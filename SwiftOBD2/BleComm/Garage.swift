//
//  Garage.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI
import Combine

struct Vehicle: Codable, Identifiable, Equatable, Hashable {
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool {
        return lhs.id == rhs.id
    }
    let id: Int
    var make: String
    var model: String
    var year: String
    var obdinfo: OBDInfo = OBDInfo()
}

class Garage: ObservableObject {
    @Published var garageVehicles: [Vehicle] = []
    @Published var currentVehicle: Vehicle? {
        didSet {
            if let currentVehicle = currentVehicle {
                currentVehicleId = currentVehicle.id
            }
        }
    }

    var currentVehicleId: Int {
        didSet {
            if currentVehicle?.make != "Mock-BMW" && currentVehicle?.make != "Mock-Toyota" {
                UserDefaults.standard.set(currentVehicleId, forKey: "currentCarId")
            }
        }
    }

    private var nextId = 0 // Initialize with the next integer ID

    init () {
        // Load garageVehicles from UserDefaults
//        UserDefaults.standard.removeObject(forKey: "garageVehicles")
//        UserDefaults.standard.removeObject(forKey: "currentCarId")
        self.currentVehicleId = UserDefaults.standard.integer(forKey: "currentCarId")

        #if targetEnvironment(simulator)
        loadMockGarage()
        #else
        loadGarage()
        #endif
    }

    func loadGarage() {
        if let data = UserDefaults.standard.data(forKey: "garageVehicles"),
           let decodedVehicles = try? JSONDecoder().decode([Vehicle].self, from: data) {
            self.garageVehicles = decodedVehicles
        } else {
            self.garageVehicles = []
        }

        // Determine the next available integer ID
        if let maxId = garageVehicles.map({ $0.id }).max() {
              self.nextId = maxId + 1
        }

        // Load currentVehicleId from UserDefaults
        self.currentVehicleId = UserDefaults.standard.integer(forKey: "currentCarId")
        currentVehicle = getVehicle(id: currentVehicleId)
    }

    func addVehicle(make: String, model: String, year: String, obdinfo: OBDInfo? = nil) {
        let vehicle = Vehicle(id: nextId, make: make, model: model, year: year, obdinfo: obdinfo ?? OBDInfo())
        garageVehicles.append(vehicle)
        nextId += 1
        saveGarageVehicles()
        currentVehicle = vehicle
    }

    func newVehicle() -> Vehicle {
        let vehicle = Vehicle(id: nextId, make: "None", model: "None", year: "2023")
        garageVehicles.append(vehicle)
        nextId += 1
        saveGarageVehicles()
        currentVehicle = vehicle
        return vehicle
    }

    // set current vehicle by id
    func setCurrentVehicle(to vehicle: Vehicle) {
        currentVehicle = vehicle
    }

    func deleteVehicle(_ car: Vehicle) {
        garageVehicles.removeAll(where: { $0.id == car.id })
        if car.id == currentVehicleId { // check if the deleted car was the current one
            currentVehicleId = garageVehicles.first?.id ?? 0 // make the first car in the garage as the current car
        }
        if car.make != "Mock-BMW" && car.make != "Mock-Toyota" {
            saveGarageVehicles()
        }
    }

    func updateVehicle(_ vehicle: Vehicle) {
        if let index = garageVehicles.firstIndex(where: { $0.id == vehicle.id }) {
            garageVehicles[index] = vehicle
            currentVehicle = vehicle
        }
        if vehicle.make != "Mock-BMW" && vehicle.make != "Mock-Toyota" {
            saveGarageVehicles()
        }
    }

    // get vehicle by id from garageVehicles
    func getVehicle(id: Int) -> Vehicle? {
        return garageVehicles.first(where: { $0.id == id })
    }

    private func saveGarageVehicles() {
        if let encodedData = try? JSONEncoder().encode(garageVehicles) {
            UserDefaults.standard.set(encodedData, forKey: "garageVehicles")
        }
    }

    func switchToDemoMode(_ isDemoMode: Bool) {
        // put garage in demo mode
        switch isDemoMode {
        case true:
            loadMockGarage()
        case false:
            loadGarage()
        }
    }

    func loadMockGarage() {
        let mockVehicle1 = Vehicle(id: 0,
                                   make: "Mock-BMW",
                                   model: "X5",
                                   year: "2015",
                                   obdinfo: OBDInfo(vin: "1234567890",
                                                    supportedPIDs: [.mode6(.MONITOR_O2_B1S1), .mode1(.speed), .mode1(.rpm), .mode1(.maf), .mode1(.throttlePos), .mode1(.coolantTemp), .mode1(.fuelLevel), .mode1(.fuelType), .mode1(.shortFuelTrim1), .mode1(.O2Bank1Sensor3), .mode1(.runTime), .mode1(.intakePressure), .mode1(.intakeTemp), .mode1(.timingAdvance), .mode1(.engineLoad)],
                                                    troubleCodes: [
                                                        TroubleCode(code: "P0000", description: "Fuel Volume Regulator Control Circuit/Open"),
                                                        TroubleCode(code: "P0001", description: "Fuel Volume Regulator Control Circuit Range/Performance"),
                                                        TroubleCode(code: "P0002", description: "Fuel Volume Regulator Control Circuit Low"),
                                                        TroubleCode(code: "P0003", description: "Fuel Volume Regulator Control Circuit High"),
                                                    ],
                                                    obdProtocol: .protocol6)
        )
        let mockVehicle2 = Vehicle(id: 1, make: "Mock-Toyota", model: "Camry", year: "2019", obdinfo: OBDInfo(obdProtocol: .protocol6))

        self.garageVehicles = [mockVehicle1, mockVehicle2]
        currentVehicle = mockVehicle1

        if let maxId = garageVehicles.map({ $0.id }).max() {
              self.nextId = maxId + 1
        }
    }
}
