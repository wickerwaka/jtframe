package main

import (
	"fmt"
	"log"
	"os"
	"strings"
	"flag"
	"sort"
	"io/ioutil"
	"path/filepath"
	"gopkg.in/yaml.v2"
)

type Origin int

const (
	GAME Origin = iota
	FRAME
	MODULE
	JTMODULE
)

type FileList struct {
	From string `yaml:"from"`
	Get []string `yaml:"get"`
	Unless string `yaml:"unless"`
}

type JTModule struct {
	Name string `yaml:"name"`
	Unless string `yaml:"unless"`
}

type JTFiles struct {
	Game [] FileList `yaml:"game"`
	JTFrame [] FileList `yaml:"jtframe"`
	Modules struct {
		JT [] JTModule `yaml:"jt"`
		Other [] FileList `yaml:"other"`
	} `yaml:"modules"`
	Here [] string `yaml:"here"`
}

type Args struct {
	Corename string
	Rel bool
	SkipVHDL bool
	Format string
	Target string
}

var parsed []string
var CWD string

func parse_args( args *Args ) {
	flag.Usage = func() {
		fmt.Fprintf(flag.CommandLine.Output(), "%s, part of JTFRAME. (c) Jose Tejada 2021.\nUsage:\n", os.Args[0])
		flag.PrintDefaults()
		os.Exit(0)
	}
	flag.StringVar(&args.Corename,"core","","core name")
	flag.StringVar(&args.Format,"f","qip","Output format. Valid values: qip, sim")
	flag.StringVar(&args.Target,"target","","Target platform: mist or mister")
	flag.BoolVar(&args.Rel,"rel",false,"Output relative paths")
	flag.BoolVar(&args.SkipVHDL,"novhdl",false,"Skip VHDL files")
	flag.Parse()
	if len(args.Corename)==0 {
		log.Fatal("JTFILES: You must specify the core name with argument -core")
	}
}

func get_filename( args Args ) string {
	cores := os.Getenv("CORES")
	if len(cores)==0 {
		log.Fatal("JTFILES: environment variable CORES is not defined")
	}
	fname := cores + "/" + args.Corename + "/hdl/game.yaml"
	return fname
}

func append_filelist( dest *[]FileList, src []FileList, other *[]string, origin Origin ) {
	if src == nil {
		return
	}
	if dest == nil {
		*dest = make( []FileList, 0 )
	}
	for _,each := range(src) {
		// If an environment variable exists with the
		// name set at "unless", the section is skipped
		if each.Unless!="" {
			_, exists := os.LookupEnv(each.Unless)
			if exists {
				continue
			}
		}
		var newfl FileList
		newfl.From = each.From
		newfl.Get = make([]string,2)
		for _,each := range(each.Get) {
			each = strings.TrimSpace(each)
			if strings.HasSuffix(each,".yaml") {
				var path string
				switch origin {
					case GAME: path = os.Getenv("CORES")+"/"+newfl.From+"/hdl/"
					case FRAME: path = os.Getenv("JTFRAME")+"/hdl/"+newfl.From+"/"
					default: path = os.Getenv("MODULES")+"/"
				}
				*other = append( *other, path+each )
			} else {
				newfl.Get = append(newfl.Get, each)
			}
		}
		if len(newfl.Get)>0 {
			found := false;
			for k,each:=range(*dest) {
				if each.From == newfl.From {
					(*dest)[k].Get = append((*dest)[k].Get, newfl.Get... )
					found = true
					break
				}
			}
			if !found {
				*dest = append( *dest, newfl )
			}
		}
	}
}

func is_parsed( name string ) bool {
	for _,k := range(parsed) {
		if name == k {
			return true
		}
	}
	return false
}

func parse_yaml( filename string, files *JTFiles ) {
	buf, err := ioutil.ReadFile(filename)
	if err != nil {
		if parsed==nil {
			log.Printf("Warning: cannot open file %s. YAML processing still used for JTFRAME board.",filename)
			return
		} else {
			log.Fatalf("cannot open referenced file %s",filename)
		}
	}
	if parsed == nil {
		parsed = make( []string, 0 )
	}
	parsed = append( parsed, filename )
	var aux JTFiles
	err_yaml := yaml.Unmarshal( buf, &aux )
	if err_yaml != nil {
		//fmt.Println(err_yaml)
		log.Fatalf("jtfiles: cannot parse file\n\t%s\n\t%v", filename, err_yaml )
	}
	other := make( []string, 0 )
	// Parse
	append_filelist( &files.Game, aux.Game, &other, GAME )
	append_filelist( &files.JTFrame, aux.JTFrame, &other, FRAME )
	append_filelist( &files.Modules.Other, aux.Modules.Other, &other, MODULE )
	if files.Modules.JT==nil {
		files.Modules.JT = make( []JTModule, 0 )
	}
	for _,each := range(aux.Modules.JT) {
		// Parse the YAML file if it exists
		fname := filepath.Join( os.Getenv("MODULES"),each.Name,"hdl",each.Name+".yaml" )
		f, err := os.Open(fname)
		if err== nil {
			f.Close()
			parse_yaml( fname, files )
		} else  {
			files.Modules.JT = append( files.Modules.JT, each )
		}
	}
	for _,each := range(other) {
		if !is_parsed(each) {
			parse_yaml( each, files )
		}
	}
	// "here" files
	if files.Here == nil {
		files.Here = make( []string, 0 )
	}
	dir := filepath.Dir( filename )
	for _,each := range(aux.Here) {
		fullpath := filepath.Join(dir, each)
		if strings.HasSuffix(each,".yaml") && !is_parsed(each) {
			parse_yaml( fullpath, files )
		} else {
			files.Here = append( files.Here, fullpath )
		}
	}
}

func make_path( path, filename string, rel bool ) (item string) {
	var err error
	oldpath := filepath.Join(path,filename)
	if rel {
		item, err = filepath.Rel(CWD,oldpath)
	} else {
		item = filepath.Clean(oldpath)
	}
	if err != nil {
		log.Fatalf("Cannot parse path to %s\n",oldpath)
	}
	return item
}

func dump_filelist( fl []FileList, all *[]string, origin Origin, rel bool ) {
	for _,each := range(fl) {
		var path string
		switch( origin ) {
			case GAME: path=filepath.Join(os.Getenv("CORES"),each.From,"hdl")
			case FRAME: path=filepath.Join(os.Getenv("JTFRAME"),"hdl",each.From)
			case MODULE: path=filepath.Join(os.Getenv("MODULES"),each.From)
			default: path=os.Getenv("JTROOT")
		}
		for _,each := range(each.Get) {
			if len(each)>0 {
				*all = append( *all, make_path(path,each,rel) )
			}
		}
	}
}

func dump_jtmodules( mods []JTModule, all *[]string, rel bool ) {
	modpath := os.Getenv("MODULES")
	if mods == nil {
		return
	}
	for _,each := range(mods) {
		if len(each.Name)>0 {
			lower := strings.ToLower(each.Name)
			lower = filepath.Join(lower,"hdl",lower+".yaml")

			*all = append( *all, make_path(modpath,lower,rel) )
		}
	}
}

func collect_files( files JTFiles, rel bool ) []string {
	all := make([]string,0)
	dump_filelist( files.Game, &all, GAME, rel )
	dump_filelist( files.JTFrame, &all, FRAME, rel )
	dump_jtmodules( files.Modules.JT, &all, rel )
	dump_filelist( files.Modules.Other, &all, MODULE, rel )
	for _,each := range(files.Here) {
		if rel {
			each,_ = filepath.Rel(CWD,each)
		}
		all = append(all,each)
	}
	sort.Strings(all)
	if len(all)>0 {
		// Remove duplicated files
		uniq := make([]string,0)
		for _,each := range(all) {
			if len(uniq)==0 || each != uniq[len(uniq)-1] {
				uniq = append( uniq, each )
			}
		}
		return uniq
	} else {
		return all
	}
}

func dump_qip( all []string, rel bool ) {
	fout, err := os.Create("game.qip")
	if err != nil {
		log.Fatal(err)
	}
	defer fout.Close()
	for _,each := range(all) {
		filetype := ""
		switch( filepath.Ext(each) ) {
			case ".sv": filetype="SYSTEMVERILOG_FILE"
			case ".vhd": filetype="VHDL_FILE"
			case ".v": filetype="VERILOG_FILE"
			case ".qip": filetype="QIP_FILE"
			default: {
				log.Fatalf("Unsupported file extension %s in file %s", filepath.Ext(each), each)
			}
		}
		aux := "set_global_assignment -name " + filetype
		if rel {
			aux = aux + "[file join $::quartus(qip_path) " + each + "]"
		} else {
			aux = aux + " " + each
		}
		fmt.Fprintln( fout, aux )
	}
}

func dump_sim( all []string, args Args ) {
	fout, err := os.Create("game.f")
	if err != nil {
		log.Fatal(err)
	}
	defer fout.Close()
	for _,each := range(all) {
		dump := true
		switch( filepath.Ext(each) ) {
			case ".sv": dump = true
			case ".vhd": dump = !args.SkipVHDL
			case ".v": dump = true
			case ".qip": dump = false
			default: {
				log.Fatalf("Unsupported file extension %s in file %s", filepath.Ext(each), each)
			}
		}
		if dump {
			fmt.Fprintln( fout, each )
		}
	}
}

func main() {
	var args Args
	parse_args(&args)
	CWD,_ = os.Getwd()

	var files JTFiles
	parse_yaml( get_filename(args), &files )
	parse_yaml( os.Getenv("JTFRAME")+"/hdl/jtframe.yaml", &files )
//	if len(args.Target)>0 {
//
//	}
	all := collect_files(files, args.Rel)

	switch( args.Format ) {
		case "qip": dump_qip(all, args.Rel )
		default: dump_sim(all, args )
	}
}