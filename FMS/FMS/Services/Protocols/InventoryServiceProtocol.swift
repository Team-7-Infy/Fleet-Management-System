//
//  InventoryServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//

import Foundation


protocol InventoryServiceProtocol: AnyObject, Sendable {
    func fetchParts() async throws -> [InventoryPart]
    func fetchPart(id: UUID) async throws -> InventoryPart
    func createPart(_ part: InventoryPart) async throws -> InventoryPart
    func updatePart(_ part: InventoryPart) async throws -> InventoryPart
    func deletePart(id: UUID) async throws
    func adjustQuantity(id: UUID, delta: Int) async throws
}
