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
		if(args.length != 2)
		{
			writefln("usage: generator xmlfile headerfile");
			return 1;
		}
		
		string xmlFile = args[0];
		string headerFile = args[1];

		Generator g = new Generator(xmlFile, headerFile);

		// TODO: Print output.		
		
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
			}
		}
		
		// TODO: put together an array of types contained in the header file.
	}

private:
	Document document;
	Element[string] m_elementMap;
	Element m_fileElement;
	string m_headerFile;
	TypeDefinition[string] m_definitionMap;
	
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
	
	bool shouldParse(Element element)
	{
		// TODO: Check to see if it is already in the type definition map.
		// TODO: Check the node type to see if it is one of the top level types we want to deal with.
	
		if("incomplete" in element.tag.attr)
		{
			return false;
		}
		
		if("file" in element.tag.attr)
		{
			return element.tag.attr["file"] == m_fileElement.tag.attr["id"];
		}
		
		return false;
	}
	
	void parseElement(Element element)
	{
		// NOTE: Don't parse types that don't make sense in C (e.g. constructors and destructors).
	
		switch(element.tag.name)
		{
            case "Enumeration":
                
				break;
            
			case "Struct":
			case "Union":
                
				break;
				
            case "Function":
			    parseFunction(element);
				break;
			
			case "Typedef":
			    
				break;

			default:
				break;
		}	
	}
	
	TypeDefinition getType(string id)
	{
		if(id in m_definitionMap)
		{
			return m_definitionMap[id];
		}
		
		assert(id in m_elementMap, "Type id is not contained in the element map.");
		parseType(m_elementMap[id]);
		assert(id in m_definitionMap, "Type id is not contained in the type definition map.");
		return m_definitionMap[id];
	}

	void parseType(Element element)
	{
		switch(element.tag.name)
		{
			case "FundamentalType":
				parseFundamentalType(element);
				break;

			case "PointerType":

				break;

			case "ArrayType":

				break;
				
			case "ReferenceType":
			
				break;
				
			case "CvQualifiedType":
			
			break;
			
			case "FunctionType":
				break;
			
            case "Enumeration":
                
				break;
            
			case "Struct":
			case "Union":
                
				break;
				
            case "Function":
			    parseFunction(element);
				break;
			
			case "Typedef":
			    
				break;

			default:
				// writefln("I don't know how to parse the type %s.", nname);
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
			}
		}
		
		assert(0, "Unrecognised FundamentalType value: " ~ name);
	}
	
	void parseFunction(Element element)
	{
	
	
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
