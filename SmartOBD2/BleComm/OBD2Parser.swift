//
//  Obd2Parser.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/7/23.
//

import Foundation

public func linesToStrArray(_ linesToParse: [String]) -> [String]{
    var allBytesTogether: [String] = []
    
    for line in linesToParse {
        let bytesArr = line.split{$0 == " "}.map(String.init)
        for bytes in bytesArr {
            allBytesTogether.append(bytes)
        }
    }
    return allBytesTogether
}

public func linesToStr(_ linesToParse: [String]) -> String{
    var endStr = ""
    
    let linesAsStrArray = linesToStrArray(linesToParse)
    
    for str in linesAsStrArray {
        endStr.append("\(str) ")
    }
    
    return endStr
}


class OBDParser: NSObject {
    
    //SINGLETON INSTANCE
    static let sharedInstance = OBDParser()
    
    override fileprivate init(){
        super.init()
    }
    
    ////////////////////////////////////////////////////////
    // MARK: PARSING
    ////////////////////////////////////////////////////////
    
    func parse_0101(_ linesToParse: [String], obdProtocol: ELM327.PROTOCOL) -> Int{
        
        let linesAsStrArr = linesToStrArray(linesToParse)
        
        if linesAsStrArr.count > 1 {
            if let numberOfDtcs = Int(linesAsStrArr[2]) {
                return numberOfDtcs - 80
            }else {
//                log.error("Number of DTCs could not be parsed from \(linesAsStrArr)")
                return 0
            }
        }else {return 0}
    }
    
    func parseDTCs(_ howMany: Int, linesToParse: [String], obdProtocol: ELM327.PROTOCOL) -> (Bool, [String]){
        
        if(howMany <= 0){
            return (false, [])
        }
        
        _ = linesToStr(linesToParse)
        
        var dtcsArray: [String] = []
        var parsingDTCs: Bool = false
        var dtcsToParse: Int = 0
        var parsedDTCs: Int = 0
        
        for line in linesToParse {
            
            let bytesArr = line.split{$0 == " "}.map(String.init)
            let count = bytesArr.count
            
            let bytePair1: String = count > 0 ? bytesArr[0] : ""
            let bytePair2: String = count > 1 ? bytesArr[1] : ""
            let bytePair3: String = count > 2 ? bytesArr[2] : ""
            let bytePair4: String = count > 3 ? bytesArr[3] : ""
            let bytePair5: String = count > 4 ? bytesArr[4] : ""
            let bytePair6: String = count > 5 ? bytesArr[5] : ""
            let bytePair7: String = count > 6 ? bytesArr[6] : ""
//            let bytePair8: String = count > 6 ? bytesArr[6] : ""
            
            
            // TODO
            
            if (bytePair1 == "43" && !parsingDTCs){ // Single line
                parsingDTCs = true
                
                //Get number of DTCs that need to be parsed
                if let dtcs = Int(bytePair2) {
                    dtcsToParse = dtcs
                }else {
                    print("Problem parsing number of DTCs")
                
                }
                
                //Parse the first line
                let dtc1 = OBDDTC.parseRawOBDErrorCode("\(bytePair3)\(bytePair4)")
                dtcsArray.append(dtc1!)
                parsedDTCs += 1
                
                if parsedDTCs == dtcsToParse { break }
                
                let dtc2 = OBDDTC.parseRawOBDErrorCode("\(bytePair5)\(bytePair6)")
                dtcsArray.append(dtc2!)
                parsedDTCs += 1
                
            }else if (bytePair1 == "0:" && bytePair2 == "43" && !parsingDTCs){ // Multiple lines
                parsingDTCs = true
                
                //Get number of DTCs that need to be parsed
                if let dtcs = Int(bytePair3) {
                    dtcsToParse = dtcs
                }else {
                    print("Problem parsing number of DTCs")
                    
                
                }
                
                let dtc1 = OBDDTC.parseRawOBDErrorCode("\(bytePair4)\(bytePair5)")
                dtcsArray.append(dtc1!)
                parsedDTCs += 1
                
                if parsedDTCs == dtcsToParse { break }
                
                let dtc2 = OBDDTC.parseRawOBDErrorCode("\(bytePair6)\(bytePair7)")
                dtcsArray.append(dtc2!)
                parsedDTCs += 1
                
            }else if parsingDTCs {
                
                if parsedDTCs == dtcsToParse { break }
                
                let dtc1 = OBDDTC.parseRawOBDErrorCode("\(bytePair2)\(bytePair3)")
                dtcsArray.append(dtc1!)
                parsedDTCs += 1
                
                if parsedDTCs == dtcsToParse { break }
                
                let dtc2 = OBDDTC.parseRawOBDErrorCode("\(bytePair4)\(bytePair5)")
                dtcsArray.append(dtc2!)
                parsedDTCs += 1
                
                if parsedDTCs == dtcsToParse { break }
                
                let dtc3 = OBDDTC.parseRawOBDErrorCode("\(bytePair6)\(bytePair7)")
                dtcsArray.append(dtc3!)
                parsedDTCs += 1
                
            }else {
                print("Problem parsing DTCs")
                
            }
            
        }
        
        return (true, dtcsArray)
    }// END of PARSE DTCs
    
}
