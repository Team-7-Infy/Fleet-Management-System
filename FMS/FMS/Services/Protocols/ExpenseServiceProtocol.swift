import Foundation

protocol ExpenseServiceProtocol: AnyObject, Sendable {
    func fetchExpenses(tripId: UUID?) async throws -> [ExpenseEntry]
    func fetchExpensesByDriver(driverId: UUID) async throws -> [ExpenseEntry]
    func fetchFuelExpenses(driverId: UUID) async throws -> [ExpenseEntry]
    func createExpense(_ entry: ExpenseEntry) async throws -> ExpenseEntry
    func deleteExpense(id: UUID) async throws
}
