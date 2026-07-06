import Foundation

protocol ExpenseServiceProtocol: AnyObject, Sendable {
    func fetchExpenses(tripId: UUID?) async throws -> [ExpenseEntry]
    func createExpense(_ entry: ExpenseEntry) async throws -> ExpenseEntry
    func deleteExpense(id: UUID) async throws
}
