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

module generator;

import std.xml, std.stdio, std.string, std.array;

version(Standalone)
{
	int main(string[] args)
	{
		if(args.length != 3)
		{
			writefln("usage: generator xmlfile headerfile");
			return 1;
		}
		
		string xmlFile = args[1];
		string headerFile = args[2];

		Generator g = new Generator(xmlFile, headerFile);
		g.generate();
		writefln("// Generated output");
		writefln(g.code);
		
		return 0;
	}
}

class Generator
{
public:
	this(string xmlFile, string headerFile)
	{
		m_headerFile = headerFile;
		string xml = cast(string)std.file.read(xmlFile);
		document = new Document(xml);
		initialiseElementMap();
	}

	void generate()
	{
		dhead = "extern(C):\n";
		
		foreach(Element element; document.elements)
		{
			switch(element.tag.name)
			{
				case "Namespace":
					parseNamespace(element);
					break;

				case "Typedef":
					parseTypedef(element);
					break;

				case "Enumeration":
					parseEnumeration(element);
					break;

				default:
					break;
			}	
		}		
	}

	@property string code()
	{
		return dhead ~ dtail;	
	}

private:
	Document document;
	Element[string] m_elementMap;
	Element m_fileElement;
	string m_headerFile;
	string dhead;
	string dtail;
	string cout;
	
	void initialiseElementMap()
	{
		foreach(Element element; document.elements)
		{
			m_elementMap[element.tag.attr["id"]] = element;
			
			if(element.tag.name == "File" && element.tag.attr["name"] == m_headerFile)
			{
				m_fileElement = element;
			}
		}	
	}
	
	string safeName(string name)
	{
		string value = name;
	
		foreach(string keyword; keywords)
		{
			if(name == keyword)
			{
				value = "_" ~ name;
				break;
			}
		}
	    
		value = replace(value, ".", "_");
		value = replace(value, "-", "_");
		return value;
	}
	
	string getName(Element element)
	{
		if("name" in element.tag.attr)
		{
			return element.tag.attr["name"];
		}
	
		return safeName(element.tag.attr["mangled"]);
	}
	
	string getDemangled(Element element)
	{
		if("demangled" in element.tag.attr)
		{
			return element.tag.attr["demangled"];
		}
		
		return element.tag.attr["name"];
	}

	string getMangled(Element element)
	{
		if("mangled" in element.tag.attr)
		{
			return element.tag.attr["mangled"];
		}
		
		return element.tag.attr["name"];
	}
	
	bool shouldParse(Element element)
	{
		// TODO: Check to see if it is already in the type definition map.
		// TODO: Check the node type to see if it is one of the top level types we want to deal with.
		// NOTE: Don't parse types that don't make sense in C (e.g. constructors and destructors).
	
		if("incomplete" in element.tag.attr)
		{
			return false;
		}
		
		if(!("file" in element.tag.attr))
		{
			return false;
		}
		
		if(element.tag.attr["file"] != m_fileElement.tag.attr["id"])
		{
			return false;
		}
		
		if("name" in element.tag.attr)
		{
			return true;
		}
		
		return false;
	}
	
	void parseNamespace(Element element)
	{
		parseMembers(element, false, true);
		parseMembers(element, false, false);		
	}
	
	void parseMembers(Element element, bool inclass, bool types)
	{
		if("members" !in element.tag.attr)
		{
			return;
		}
		
		string[] members = split(element.tag.attr["members"]);
		
		foreach (member; members)
		{
			parseElement(m_elementMap[member], inclass, types);
		}		
	}
	
	void parseElement(Element element, bool inclass, bool types)
	{
		if(!shouldParse(element))
		{
			return;
		}		
		
		switch(element.tag.name)
		{
			case "Struct":
			case "Union":
				parseStruct(element);			
				break;

			case "Variable":
			case "Field":			
				parseVariable(element, inclass);
				break;
			
			case "Function":
				parseFunction(element);
				break;
			
			case "Typedef":
				parseTypedef(element);
				break;
				
            case "Enumeration":
				parseEnumeration(element);
				break;

			default:
				writefln("I don't know how to parse the element %s.", element.tag.name);
				break;
		}	
	}	
	
	void parseStruct(Element element)
	{
		string name = getName(element);
		string mangled = getMangled(element);
		string demangled = getDemangled(element);
		
		if (element.tag.name == "Union") {
			dtail ~= "union ";
		} else {
			dtail ~= "struct ";
		}
		dtail ~= name ~ " {\n";
		
		parseMembers(element, true, false);
		dtail ~= "}\n";
	}
	
	void parseVariable(Element element, bool inclass)
	{
		ParsedType type = parseType(element.tag.attr["type"]);
		string name = getName(element);
       
        dtail ~= type.DType ~ " " ~ safeName(name) ~ ";\n";
	}
	
	void parseFunction(Element element)
	{
		string name = getName(element);
		string mangled = getMangled(element);
		string demangled = getDemangled(element);
		ParsedType type = parseType(element.tag.attr["returns"]);
		
		string Dargs;
		string Deargs;
		string Cargs;
		string Dcall;
		string Ccall;
		
		// the demangled name includes ()
		auto demparen = indexOf(demangled, '(');
		if (demparen != -1) {
			demangled = demangled[0..demparen];
		}
		
		parseArguments(element, Dargs, Deargs, Cargs, Dcall, Ccall);
		parseFunctionBody(element, safeName(name), mangled, demangled, type,
							Dargs, Deargs, Cargs, Dcall, Ccall);
	}
	
	void parseArguments(Element element, ref string Dargs, ref string Deargs,
                     ref string Cargs, ref string Dcall,
                     ref string Ccall)
	{
		int onParam = 0;

		foreach(Element argument; element.elements)
		{
			switch(argument.tag.name)
			{
				case "Argument":
					ParsedType atype = parseType(argument.tag.attr["type"]);
					string aname = getName(argument);
					if (aname == "") aname = "_" ~ std.conv.to!string(onParam);
					aname = safeName(aname);
					
					if (Dargs != "") {
						Dargs ~= ", ";
					}
					Dargs ~= atype.DType ~ " " ~ aname;
					
					if (atype.isClass || atype.isClassPtr) {
						// this becomes a void * in D's view
						if (Deargs != "") {
							Deargs ~= ", ";
						}
						Deargs ~= "void*" ~ aname;
					} else {
						if (Deargs != "") {
							Deargs ~= ", ";
						}
						Deargs ~= atype.DType ~ " " ~ aname;
					}
					
					if (Cargs != "") {
						Cargs ~= ", ";
					}
					Cargs ~= atype.CType ~ " " ~ aname;
					
					if (Dcall != "") {
						Dcall ~= ", ";
					}
					Dcall ~= aname;
					if (atype.isClass || atype.isClassPtr) {
						// turn this into the real info
						Dcall ~= ".__C_data";
					}
					
					if (atype.isClass) {
						// need to dereference
						if (Ccall != "") {
							Ccall ~= ", ";
						}
						Ccall ~= "*" ~ aname;
					} else {
						if (Ccall != "") {
							Ccall ~= ", ";
						}
						Ccall ~= aname;
					}
					break;
					
				case "Ellipsis":
					if (Dargs != "") {
						Dargs ~= ", ";
					}
					Dargs ~= "...";
					
					if (Deargs != "") {
						Deargs ~= ", ";
					}
					Deargs ~= "...";
					
					if (Cargs != "") {
						Cargs ~= ", ";
					}
					Cargs ~= "...";
					
					if (Dcall != "") {
						Dcall ~= ", ";
					}
					Dcall ~= "...";
					
					if (Ccall != "") {
						Ccall ~= ", ";
					}
					Ccall ~= "...";
					
				default:
					writefln("I don't know how to parse %s!", argument.tag.name);
					break;
			}
				
			onParam++;
		}
	}

	void parseFunctionBody(Element element, string name, string mangled, string demangled, ParsedType type,
							 string Dargs, string Deargs, string Cargs, string Dcall, string Ccall)
	{
		dhead ~= type.DType ~ " " ~ demangled ~ "(" ~ Deargs ~ ");\n";
	}
	
	void parseTypedef(Element element)
	{
		static bool[string] handledTypedefs;
		
		auto pt = parseType(element.tag.attr["type"]);
		string aname = getName(element);
		string type = element.tag.attr["id"];
		
		if (!(type in handledTypedefs))
		{
			handledTypedefs[type] = true;
			
			cout ~= "typedef " ~ pt.CType ~ " _rebound_" ~ aname ~ ";\n";
			
			if (element.tag.attr["file"] == m_fileElement.tag.attr["id"])
				dhead ~= "alias " ~ pt.DType ~ " " ~ aname ~ ";\n";
		}
	}

	void parseEnumeration(Element element)
	{
		static bool[string] handledEnums;
		
		string aname = getName(element);
		if (aname == "") return;
		string type = element.tag.attr["id"];
		
		// make an enum in D as well
		if (!(type in handledEnums)) {
			handledEnums[type] = true;
			
			if (element.tag.attr["file"] != m_fileElement.tag.attr["id"]) return;
			if (aname[0] == '.') return;
			
			dhead ~= "enum " ~ safeName(aname) ~ " {\n";
			
			foreach(Element childElement; element.elements)
			{
				if(childElement.tag.name == "EnumValue")
				{
					dhead ~= safeName(getName(childElement)) ~ " = " ~
							 childElement.tag.attr["init"] ~ ",\n";
				}
				else
				{
					writefln("I don't know how to parse %s!", childElement.tag.name);
				}
			}

			dhead ~= "}// parseEnumeration(" ~ type ~ ")\n";
		}
	}

	/**
	 * Get the type of a node in C[++] and D
	 */
	ParsedType parseType(string type)
	{
		auto element = m_elementMap[type];

		switch(element.tag.name)
		{
			case "FundamentalType":
				string ctype = getName(element);
				
				foreach(string[2] typename; fundamentalTypeMap)
				{
					if(ctype == typename[0])
					{
						return new ParsedType(ctype, typename[1]);
					}
				}
				
				writefln("I don't know how translate %s to D.", ctype);
				return new ParsedType("void*", "void*");	
			
			case "PointerType":
				auto baseType = parseType(element.tag.attr["type"]);
				// functions and classes are already pointers
				if (!baseType.isClass && !baseType.isFunction) {
					baseType.CType ~= "*";
					baseType.DType ~= "*";
				} else if (baseType.isClass) {
					ParsedType pt = new ParsedType(baseType);
					pt.DType ~= "*";
					pt.isClassPtr = true;
					return pt;
				}
				
				return new ParsedType(baseType);
			
			case "ArrayType":
				auto baseType = parseType(element.tag.attr["type"]);
				int size = std.c.stdlib.atoi(element.tag.attr["max"].toStringz()) + 1;
				baseType.CType = "_rebound_array_" ~ type;
				baseType.DType ~= "[" ~ std.conv.to!string(size) ~ "]";		
				return new ParsedType(baseType);
				
			case "ReferenceType":
				auto baseType = parseType(element.tag.attr["type"]);
				
				if (!baseType.isClass)
				{
					baseType.CType ~= "&";
					baseType.DType ~= "*";
				} 
				else
				{
					// we need to treat this as a pointer in D, but a reference in C
					
					// 1) cut off the *
					baseType.CType = baseType.CType[0 .. baseType.CType.length - 1];
					
					// 2) add the &
					baseType.CType ~= "&";
					
					ParsedType pt = new ParsedType(baseType);
					pt.isClassPtr = true;
					return pt;
				}
				
				return new ParsedType(baseType);
			
			case "Struct":
			case "Class":
				string className = element.tag.attr["demangled"];
				ParsedType pt;
				
				// can't have incomplete types in D, so call it a BoundClass in D
				if ("incomplete" in element.tag.attr) {
					pt = new ParsedType(className ~ "*",
										"rebound.bind.BoundClass");
				} else {
					pt = new ParsedType(className ~ "*",
										safeName(getName(element)));
				}
				pt.className = className;
				pt.isClass = true;
				return pt;
			
			case "Union":
				string className = element.tag.attr["demangled"];
				
				if ("incomplete" in element.tag.attr)
				{
					return new ParsedType("union " ~ className,
										  "void");
				} 
				else 
				{
					return new ParsedType("union " ~ className,
										  safeName(getName(element)));
				}
				
			case "CvQualifiedType":
				// this is just a const
				auto pt = parseType(element.tag.attr["type"]);
				if (pt.CType.length < 6 ||
					pt.CType[0..6] != "const ")
					pt.CType = "const " ~ pt.CType;
				return pt;
				
			case "Typedef":
				// this is also an alias, but we should replicate it in D
				auto pt = parseType(element.tag.attr["type"]);
				string aname = getName(element);
				
				//parseTypedef(element);
				
				ParsedType rpt = new ParsedType("_rebound_" ~ aname, pt.DType);
				rpt.isClass = pt.isClass;
				rpt.isFunction = pt.isFunction;
				return rpt;
				
			case "FunctionType":
				// make a typedef and an alias
				static bool[string] handledFunctions;
				
				if (!(type in handledFunctions)) {
					handledFunctions[type] = true;
					
					auto pt = parseType(element.tag.attr["returns"]);
					string couta, dheada;
					
					bool first = true;
					couta = "typedef " ~ pt.CType ~
					" (*_rebound_func_" ~ type ~ ")(";
					dheada = "alias " ~ pt.DType ~ " function(";
					
					// now look for arguments
					foreach(Element argument; element.elements)
					{
						auto argType = parseType(argument.tag.attr["type"]);
						
						if (!first) {
							couta ~= ", ";
							dheada ~= ", ";
						} else {
							first = false;
						}
						
						couta ~= argType.CType;
						dheada ~= argType.DType;				
					}
					
					cout ~= couta ~ ");\n";
					dhead ~= dheada ~ ") _rebound_func" ~ type ~ ";\n";
				}
				
				ParsedType pt = new ParsedType("_rebound_func" ~ type, "_rebound_func" ~ type);
				pt.isFunction = true;
				return pt;
			 
			case "Enumeration":
				parseEnumeration(element);
				
				// if this is fake, ignore it
				string aname = getName(element); 
				if (aname[0] == '.') {
					return new ParsedType("int", "int");
				}
				
				/* we need the demangled name in C, but there is no demangled=
				 * for enumerations, so we need the parent */
				if("context" in element.tag.attr)
				{
					string scontext = element.tag.attr["context"];
					Element pnode = m_elementMap[scontext];
					string demangled = getDemangled(pnode);
					
					if (demangled != "" && demangled != "::")
					{
						return new ParsedType("enum " ~ demangled ~ "::" ~ aname, "int");
					}			
				}
				
				return new ParsedType("enum " ~ aname, "int");

			default:
				writefln("I don't know how to parse the type %s.", element.tag.name);
				return new ParsedType("void*", "void*");
		}
	}
}

/**
 * A type in both C[++] and D
 */
class ParsedType {
    this(string sCType, string sDType)
    {
        CType = sCType;
        DType = sDType;
    }
    this(ParsedType copy)
    {
        CType = copy.CType;
        DType = copy.DType;
    }
    string CType;
    string DType;
    string className;
    bool isClass;
    bool isClassPtr;
    bool isFunction;
}

private string[2][16] fundamentalTypeMap = 
	[
		["void", "void"],
		["long long int", "long"],
		["long long unsigned int", "ulong"],
		["long int", "int"],
		["long unsigned int", "uint"],
		["int", "int"],
		["unsigned int", "uint"],
		["short int", "short"],
		["short unsigned int", "ushort"],
		["char", "char"],
		["signed char", "char"],
		["unsigned char", "char"],
		["bool", "bool"],
		["long double", "real"],
		["double", "double"],
		["float", "float"]
	];
	
private string[11] keywords = 
	[
		"alias",
		"align",
		"body",
		"function",
		"in", 
		"inout", 
		"module", 
		"out", 
		"override", 
		"scope", 
		"version"
	];
