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
	
		foreach(TypeDefinition definition; g.types)
		{
			writefln(definition.code);
		}		
		
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
		foreach(Element element; document.elements)
		{
			if(shouldParse(element))
			{
				parseElement(element);
				
				if(element.tag.attr["id"] in m_definitionMap)
				{
					m_types ~= m_definitionMap[element.tag.attr["id"]];
				}
			}
		}
		
		// TODO: sort types array.
	}

	@property TypeDefinition[] types()
	{
		return m_types;	
	}

private:
	Document document;
	Element[string] m_elementMap;
	Element m_fileElement;
	string m_headerFile;
	TypeDefinition[string] m_definitionMap;
	TypeDefinition[] m_types;
	
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
	
	string[] getMembers(Element element)
	{
		string[] members;
		
		if("members" in element.tag.attr)
		{
			members = split(element.tag.attr["members"]);
		}
		
		return members;
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
	
	TypeDefinition getType(string id)
	{
		if(id in m_definitionMap)
		{
			return m_definitionMap[id];
		}
		
		assert(id in m_elementMap, format("Type id %s is not contained in the element map.", id));
		parseElement(m_elementMap[id]);
		assert(id in m_definitionMap, format("Type id %s is not contained in the type definition map.", id));
		return m_definitionMap[id];
	}

	void parseElement(Element element)
	{
		switch(element.tag.name)
		{
			case "FundamentalType":
				parseFundamentalType(element);
				break;

			case "PointerType":
				parsePointerType(element);
				break;

			case "ArrayType":

				break;
				
			case "ReferenceType":
			
				break;
				
			case "CvQualifiedType":
				parseCvQualifiedType(element);
				break;
			
			case "FunctionType":
				break;
			
            case "Enumeration":
                parseEnumeration(element);
				break;
            
			case "Struct":
			case "Union":
                parseStruct(element);
				break;
				
            case "Function":
			    parseFunction(element);
				break;
			
			case "Typedef":
			    
				break;

			default:
				writefln("I don't know how to parse the element %s.", element.tag.name);
				break;
		}	
	}
	
	void parseFundamentalType(Element element)
	{
		string name = element.tag.attr["name"];
	
		foreach(string[2] typename; fundamentalTypeMap)
		{
			if(name == typename[0])
			{
				auto td = new TypeDefinition(element, typename[1]);
				m_definitionMap[element.tag.attr["id"]] = td;
				return;
			}
		}
		
		assert(0, "Unrecognised FundamentalType value: " ~ name);
	}
	
	void parseFunction(Element element)
	{

	}
	
	void parseEnumeration(Element element)
	{
		string code = format("enum %s {\n", safeName(element.tag.attr["name"]));
		
		foreach(Element enumValue; element.elements)
		{
			if(enumValue.tag.name != "EnumValue")
			{
				continue;
			}
			
			code ~= format("\t%s = %s,\n", safeName(enumValue.tag.attr["name"]), enumValue.tag.attr["init"]);
		}
		
		code ~= "}\n";
		
		auto td = new TypeDefinition(element, code);
		m_definitionMap[td.id] = td;
	}
	
	void parsePointerType(Element element)
	{
		TypeDefinition baseType = getType(element.tag.attr["type"]);
		string code = format("%s *", baseType.code);
		auto td = new TypeDefinition(element, code);
		m_definitionMap[td.id] = td;
	}
	
	void parseCvQualifiedType(Element element)
	{
		TypeDefinition baseType = getType(element.tag.attr["type"]);
		string code = format("const %s", baseType.code);
		auto td = new TypeDefinition(element, code);
		m_definitionMap[td.id] = td;
	}
	
	void parseTypedef(Element element)
	{
		TypeDefinition baseType = getType(element.tag.attr["type"]);
		string code = format("const %s", baseType.code);
		auto td = new TypeDefinition(element, code);
		m_definitionMap[td.id] = td;
	}
	
	void parseStruct(Element element)
	{
		string prefix;
		
		if(element.tag.name == "Union")
		{
			prefix = "union %s {\n";
		}
		else
		{
			prefix = "struct %s {\n";
		}
	
		string code = format(prefix, getName(element));
		
		string[] members = getMembers(element);
		
		foreach(string member; members)
		{
			Element field = m_elementMap[member];
			assert(field.tag.name == "Field");
			TypeDefinition type = getType(field.tag.attr["type"]);
			code ~= format("%s %s;\n", safeName(field.tag.attr["name"]), type.code);
		}
		
		code ~= "}\n";
		
		auto td = new TypeDefinition(element, code);
		m_definitionMap[td.id] = td;
	}
}

class TypeDefinition
{
public:
	this(Element element, string code)
	{
		m_code = code;
		m_element = element;
	}

	@property
	{
		string id()
		{
			return m_element.tag.attr["id"];
		}
		
		string name()
		{
			return m_element.tag.attr["name"];
		}
		
		string file()
		{
			return m_element.tag.attr["file"];
		}

		string line()
		{
			return m_element.tag.attr["line"];
		}
		
		string code()
		{
			return m_code;
		}
	}
	
	string toString()
	{
		return m_code;
	}
	
	override int opCmp(Object o)
	{
		auto other = cast(TypeDefinition) o;
		int result = std.algorithm.cmp(file, other.file);
	
		if(result != 0)
		{
			return result;
		}
	
		return std.algorithm.cmp(line, other.line);
	}

protected:	
	Element m_element;
	string m_code;	
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
