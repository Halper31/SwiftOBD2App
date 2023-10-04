//
//  Decoders.swift
//  SmartOBD2
//
//  Created by kemo konteh on 9/18/23.
//

import Foundation

func bytesToInt(_ byteArray: Data) -> Int {
    var value = 0
    var power = 0

    for byte in byteArray.reversed() {
        value += Int(byte) << power
        power += 8
    }
    return value
}

struct BitArray {
    private var data: Data
    var binaryArray: [Int] = []

    init(data: Data) {
        self.data = data
        for byte in data {
            for bit in 0..<8 {
                binaryArray.append(Int((byte >> UInt8(7 - bit)) & 1))
            }
        }
    }

    subscript(index: Int) -> Bool {
        let byteIndex = index / 8
        let bitIndex = index % 8
        return (data[byteIndex] & UInt8(1 << bitIndex)) != 0
    }

    func value(at range: Range<Int>) -> UInt8 {
        var value: UInt8 = 0
        for bit in range {
            value = value << 1
            value = value | UInt8(binaryArray[bit])
        }
        return value
    }
}

extension Unit {
    static let percent = Unit(symbol: "%")
    static let count = Unit(symbol: "count")
    static let degreeCelsius = Unit(symbol: "°C")
    static let kph = Unit(symbol: "kph")
    static let rpm = Unit(symbol: "rpm")
    static let kilopascal = Unit(symbol: "kPa")
}

let uasIDS: [UInt8: UAS] = [
    // Unsigned
    0x01: UAS(signed: false, scale: 1.0, unit: Unit.count),
    0x02: UAS(signed: false, scale: 0.1, unit: Unit.count),
    0x07: UAS(signed: false, scale: 0.25, unit: Unit.rpm),
    0x09: UAS(signed: false, scale: 1, unit: Unit.kph),
    0x12: UAS(signed: false, scale: 1, unit: UnitDuration.seconds),

    // Signed
    0x81: UAS(signed: true, scale: 1.0, unit: Unit.count),
    0x82: UAS(signed: true, scale: 0.1, unit: Unit.count)
]

enum Decoder: Codable {
    case pid
    case status
    case singleDTC
    case fuelStatus
    case percent
    case temp
    case percentCentered
    case fuelPressure
    case pressure
    case uas0x07
    case uas0x09
//    case uas0x12
    case timingAdvance
    case uas0x27
    case airStatus
//    case o2Sensors
//    case sensorVoltage
//    case obdCompliance
//    case o2SensorsAlt
//    case auxInputStatus
//    case uas0x25
//    case uas0x19
//    case uas0x1B
//    case uas0x01
//    case uas0x16
//    case uas0x0B
//    case uas0x1E
//    case evapPressure
//    case sensorVoltageBig
    case currentCentered
//    case absoluteLoad
//    case drop
//    case uas0x34
//    case maxMaf
//    case fuelType
//    case absEvapPressure
//    case evapPressureAlt
//    case injectTiming
//    case dtc
//    case fuelRate

    func decode(data: [Message]) -> Any? {
        switch self {
        case .pid:                   return nil
        case .status:                return status(data)
        case .uas0x09:               return decodeUAS(data, id: 0x09)
        case .uas0x07:               return decodeUAS(data, id: 0x07)
        case .temp:                  return temp(data)
        case .percent:               return percent(data)
        case .currentCentered:       return currentCentered(data)
        case .airStatus:             return airStatus(data)
        case .singleDTC:             return singleDtc(data)
        case .fuelStatus:            return nil
        case .percentCentered:       return percentCentered(data)
        case .fuelPressure:          return fuelPressure(data)
        case .pressure:              return pressure(data)
        case .timingAdvance:         return timingAdvance(data)
        case .uas0x27:               return decodeUAS(data, id: 0x27)

        }
    }

    func decodeUAS(_ messages: [Message], id: UInt8) -> Measurement<Unit>? {
        let bytes = messages[0].data[2...]
        return uasIDS[id]?.decode(bytes: bytes)
    }

    func singleDtc(_ messages: [Message]) -> String? {
        let data = messages[0].data[2...]
        return parseDTC(data)
    }

    func parseDTC(_ data: Data) -> String? {
        if (data.count != 2) || (data == Data([0x00, 0x00])) {
            return nil
        }

        // BYTES: (16,      35      )
        // HEX:    4   1    2   3
        // BIN:    01000001 00100011
        //         [][][  in hex   ]
        //         | / /
        // DTC:    C0123
        var dtc = ["P", "C", "B", "U"][Int(data[0]) >> 6]  // the last 2 bits of the first byte
        dtc += String((data[0] >> 4) & 0b0011)  // the next pair of 2 bits. Mask off the bits we read above
        let dtcString = dtc
        return dtcString
    }

//    func fuelStatus(_ messages: [Message]) -> (String?, String?) {
//        guard let data = messages.first?.data.dropFirst(2) else {
//            return (nil, nil)
//        }
//        
//        let FUEL_STATUS = ["Status1", "Status2", "Status3"]
//
//        let bits = BitArray(data: data).binaryArray
//
//        var status1: String? = nil
//        var status2: String? = nil
//        
//        if bits[0..<8].count(1) == 1 {
//                if let index = bits[0..<8].firstIndex(of: true), 7 - index < FUEL_STATUS.count {
//                    status1 = FUEL_STATUS[7 - index]
//                } else {
//                    NSLog("Invalid response for fuel status (high bits set)")
//                }
//            } else {
//                NSLog("Invalid response for fuel status (multiple/no bits set)")
//            }
//
//            if bits[8..<16].count(true) == 1 {
//                if let index = bits[8..<16].firstIndex(of: true), 7 - index < FUEL_STATUS.count {
//                    status2 = FUEL_STATUS[7 - index]
//                } else {
//                    NSLog("Invalid response for fuel status (high bits set)")
//                }
//            } else {
//                NSLog("Invalid response for fuel status (multiple/no bits set)")
//            }
//
//            return (status1, status2)
//    }

    // 0 to 765 kPa
    func fuelPressure(_ messages: [Message]) -> Measurement<Unit>? {
        let data = messages[0].data[2...]
        var value = data[0]
        value *= 3
        return Measurement(value: Double(value), unit: .kilopascal)
    }

    // 0 to 255 kPa
    func pressure(_ messages: [Message]) -> Measurement<Unit>? {
        let data = messages[0].data[2...]
        let value = data[0]
        return Measurement(value: Double(value), unit: .kilopascal)
    }

    func percent(_ messages: [Message]) -> Measurement<Unit>? {
        let data = messages[0].data[2...]
        var value = Double(data[0])
        value = value * 100.0 / 255.0
        return Measurement(value: value, unit: .percent)
    }

    func percentCentered(_ messages: [Message]) -> Measurement<Unit>? {
        let data = messages[0].data[2...]
        var value = Double(data[0])
        value = (value - 128) * 100.0 / 128.0
        return Measurement(value: value, unit: .percent)
    }

    func currentCentered(_ messages: [Message]) -> Measurement<Unit>? {
         let data = messages[0].data[2...]
            let value = (Double(bytesToInt(data[2..<4])) / 256.0) - 128.0
         return Measurement(value: value, unit: UnitElectricCurrent.milliamperes)
     }

    func airStatus(_ messages: [Message]) -> Measurement<Unit>? {
           let data = messages[0].data[2...]
           let bits = BitArray(data: data).binaryArray

           let numSet = bits.filter { $0 == 1 }.count
           if numSet == 1 {
               let index = 7 - bits.firstIndex(of: 1)!
               return Measurement(value: Double(index), unit: Unit.count)
           }
           return nil
       }

    func temp(_ messages: [Message]) -> Measurement<Unit>? {
        let data = messages[0].data[2...]
        let value = Double(bytesToInt(data)) - 40.0
        return Measurement(value: value, unit: UnitTemperature.celsius)
    }

    func timingAdvance(_ messages: [Message]) -> Measurement<Unit>? {
            let data = messages[0].data[2...]
            let value = (Double(data[0]) - 128) / 2.0
            return Measurement(value: value, unit: UnitAngle.degrees)
    }

    func status(_ messages: [Message]) -> Status {
        let data = messages[0].data[2...]
        let IGNITIONTYPE = ["Spark", "Compression"]

        //            ┌Components not ready
        //            |┌Fuel not ready
        //            ||┌Misfire not ready
        //            |||┌Spark vs. Compression
        //            ||||┌Components supported
        //            |||||┌Fuel supported
        //  ┌MIL      ||||||┌Misfire supported
        //  |         |||||||
        //  10000011 00000111 11111111 00000000
        //  00000000 00000111 11100101 00000000
        //  10111110 00011111 10101000 00010011
        //   [# DTC] X        [supprt] [~ready]

        // convert to binaryarray
        let bits = BitArray(data: data)

        var output = Status()
        output.MIL = bits.binaryArray[0] == 1
        output.dtcCount = bits.value(at: 1..<8)
        output.ignitionType = IGNITIONTYPE[bits.binaryArray[12]]

        // load the 3 base tests that are always present

        for (index, name) in baseTests.reversed().enumerated() {
            processBaseTest(name, index, bits, &output)
        }
        return output
    }

    func processBaseTest(_ testName: String, _ index: Int, _ bits: BitArray, _ output: inout Status) {
        let test = StatusTest(testName, (bits.binaryArray[13 + index] != 0), (bits.binaryArray[9 + index] == 0))
        switch testName {
        case "MISFIRE_MONITORING":
            output.misfireMonitoring = test
        case "FUEL_SYSTEM_MONITORING":
            output.fuelSystemMonitoring = test
        case "COMPONENT_MONITORING":
            output.componentMonitoring = test
        default:
            break
        }
    }

}

struct UAS {
    let signed: Bool
    let scale: Double
    let unit: Unit
    let offset: Double

    init(signed: Bool, scale: Double, unit: Unit, offset: Double = 0.0) {
        self.signed = signed
        self.scale = scale
        self.unit = unit
        self.offset = offset
    }

    func twosComp(_ value: Int, length: Int) -> Int {
        let mask = (1 << length) - 1
        return value & mask
    }

    func decode(bytes: Data) -> Measurement<Unit>? {
        var value = bytesToInt(bytes)

        if signed {
            value = twosComp(value, length: bytes.count * 8)
        }

        let scaledValue = Double(value) * scale + offset
        return Measurement(value: scaledValue, unit: unit)
    }
}

let baseTests = [
    "MISFIRE_MONITORING",
    "FUEL_SYSTEM_MONITORING",
    "COMPONENT_MONITORING"
]

let sparkTests = [
    "CATALYST_MONITORING",
    "HEATED_CATALYST_MONITORING",
    "EVAPORATIVE_SYSTEM_MONITORING",
    "SECONDARY_AIR_SYSTEM_MONITORING",
    nil,
    "OXYGEN_SENSOR_MONITORING",
    "OXYGEN_SENSOR_HEATER_MONITORING",
    "EGR_VVT_SYSTEM_MONITORING"
]

let compressionTests = [
    "NMHC_CATALYST_MONITORING",
    "NOX_SCR_AFTERTREATMENT_MONITORING",
    nil,
    "BOOST_PRESSURE_MONITORING",
    nil,
    "EXHAUST_GAS_SENSOR_MONITORING",
    "PM_FILTER_MONITORING",
    "EGR_VVT_SYSTEM_MONITORING"
]
