//
//  AuthServiceProtocol.swift
//  FMS
//
//  Created by Veer on 26/06/26.
//


import Foundation

protocol AuthServiceProtocol: AnyObject, Sendable {
    func signUp(email: String, password: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() async throws
    func currentSession() async throws -> User?
    func deleteAccount() async throws
    func createAuthIdentity(email: String, password: String) async throws -> UUID
    func inviteUser(email: String, password: String, displayName: String) async throws -> UUID
    func sendRecoveryOTP(email: String) async throws
    func verifyOTP(email: String, token: String) async throws
    func updateUserPassword(password: String) async throws
    func forceUpdatePassword(userId: UUID, password: String) async throws
    func markFirstTimeLoginComplete(userId: UUID) async throws
    func deleteUserAuth(userId: UUID) async throws
}