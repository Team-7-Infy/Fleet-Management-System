//
//  AuthServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


protocol AuthServiceProtocol: AnyObject, Sendable {
    func signUp(email: String, password: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() async throws
    func currentSession() async throws -> User?
    func deleteAccount() async throws
}