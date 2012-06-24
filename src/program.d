/**
 * Generate bindings for C in D
 * 
 * Authors: Gregor Richards
 *          David Feilen
 * 
 * License:
 *  Copyright (C) 2006  Gregor Richards
 *  Copyright (C) 2012  David Feilen
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

module program;

import std.stdio, std.array, std.path, std.file, std.process, std.string;
import generator;

Parameters parameters;

int main(string[] args)
{
	parameters.verbose = true;
	
	if(!parseParameters(parameters, args))
	{
		printUsage();
		return 1;
	}

	if(parameters.help)
	{
		printUsage();
		return 0;
	}

	if(!validateParameters(parameters))
	{
		printUsage();
		return 2;
	}

	if(parameters.verbose)
	{
		printParameters(parameters);
	}
	
	if(!generateXml())
	{
		return 3;		
	}
	
	auto g = new Generator("out.xml", parameters.file);
	g.generate();

	writeOutput(parameters, g.code);
	
	return 0;
}

void printUsage() {
	writefln(q"EOS
Use:
rebound [options] <.h file>
Options:
  -I<include prefix>
  -F<forced import>
  --help, -h
     Display this message.
EOS");
	
}

struct Parameters {
	string file;
	string[] includePaths;
	string[] importModules;
	string moduleName;
	bool help;
	bool verbose;
}

bool parseParameters(ref Parameters parameters, string[] args)
{
	if(args.length < 2)
	{
		writefln("header file is required.");
		return false;
	}

	auto maxArgumentIndex = args.length - 1;

	for(auto i = 1; i <= maxArgumentIndex; i++)
	{
		if(args[i].length > 2)
		{
			switch(args[i][0..2])
			{
				case "-I":
					parameters.includePaths ~= args[i][2..args[i].length];
					break;
				
				case "-F":
					parameters.importModules ~= args[i][2..args[i].length];
					break;
					
				default:
					if(args[i] == "--help")
					{
						parameters.help = true;
						break;
					}
				
					if(i < maxArgumentIndex)
					{
						writefln("Invalid argument: %s", args[i]);
						return false;
					}
				
					parameters.file = args[i];				
					break;	
			}
		}
		else
		{
			if(args[i] == "-h")
			{
				parameters.help = true;
				continue;
			}
		
			if(i < maxArgumentIndex)
			{
				writefln("Invalid argument: %s", args[i]);
				return false;
			}
		
			parameters.file = args[i];				
			continue;
		}		
	}

	return true;
}

bool validateParameters(ref Parameters parameters)
{
	parameters.file = absolutePath(parameters.file);
	parameters.moduleName = baseName(stripExtension(parameters.file));
	
	if(!exists(parameters.file))
	{
		writefln("File \"%s\" doesn't exist.", parameters.file);
		return false;
	}
	
	return true;
}

void printParameters(ref Parameters parameters)
{
	writefln("File: %s", parameters.file);
	writefln("Include path: %s", join(parameters.includePaths, "\nInclude path: "));
	writefln("Import modules: %s", join(parameters.importModules, ", "));
	writefln("Module name: %s", parameters.moduleName);
	writefln("Help: %s", parameters.help);
	writefln("Verbose: %s", parameters.verbose);
}

bool generateXml()
{
	string cflags = getenv("CFLAGS");
	string includes = "";
	
	if(parameters.includePaths.length > 0)
	{
		includes = std.string.format("-I%s", join(parameters.includePaths, " -I"));
	}
	
	string cmd = std.string.format("gccxml %s %s -fxml=out.xml %s", cflags, includes, parameters.file);

	auto status = system(cmd);

	if(status == 0)
	{
		return true;
	}
	
	writefln("gccxml execution failed.");
	return false;
}

void writeOutput(ref Parameters parameters, string data)
{
	string filename = parameters.moduleName ~ ".d";
	
	auto f = File(filename, "w");
	f.write(format("module %s;\n\n", parameters.moduleName));
	
	foreach(string importModule; parameters.importModules)
	{
		f.write(format("import %s;\n", importModule));
	}
	
	f.write(data);
	f.close();
}
