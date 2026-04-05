-- Modern Bank - SQL Server Schema
-- Deploy on Windows 10 with SQL Server Express
-- Database: ModernBank

USE master;
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'ModernBank')
    CREATE DATABASE ModernBank;
GO

USE ModernBank;
GO

-- ============================================================================
-- Users Table
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
CREATE TABLE Users (
    UserID INT PRIMARY KEY IDENTITY(1,1),
    Username NVARCHAR(50) UNIQUE NOT NULL,
    Email NVARCHAR(100) UNIQUE NOT NULL,
    PasswordHash NVARCHAR(255) NOT NULL,
    FullName NVARCHAR(100) NOT NULL,
    PhoneNumber NVARCHAR(20),
    AccountType NVARCHAR(20) DEFAULT 'Standard',  -- Standard, Premium, Admin
    CreatedDate DATETIME DEFAULT GETDATE(),
    LastLogin DATETIME,
    IsActive BIT DEFAULT 1,
    
    INDEX idx_username (Username),
    INDEX idx_email (Email)
);
GO

-- ============================================================================
-- Accounts Table (Banking Accounts)
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Accounts')
CREATE TABLE Accounts (
    AccountID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT NOT NULL,
    AccountNumber NVARCHAR(50) UNIQUE NOT NULL,
    AccountType NVARCHAR(50),  -- Checking, Savings, Credit Card
    Balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    CurrencyCode NVARCHAR(3) DEFAULT 'USD',
    Status NVARCHAR(20) DEFAULT 'Active',
    CreatedDate DATETIME DEFAULT GETDATE(),
    LastModified DATETIME DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    INDEX idx_user (UserID),
    INDEX idx_status (Status)
);
GO

-- ============================================================================
-- Transactions Table
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Transactions')
CREATE TABLE Transactions (
    TransactionID INT PRIMARY KEY IDENTITY(1,1),
    FromAccountID INT,
    ToAccountID INT,
    Amount DECIMAL(15, 2) NOT NULL,
    TransactionType NVARCHAR(50),  -- Deposit, Withdrawal, Transfer, Purchase
    Description NVARCHAR(255),
    Category NVARCHAR(50),  -- Shopping, Utilities, Salary, etc.
    TransactionDate DATETIME DEFAULT GETDATE(),
    Status NVARCHAR(20) DEFAULT 'Completed',  -- Pending, Completed, Failed
    ReferenceNumber NVARCHAR(50) UNIQUE,
    
    FOREIGN KEY (FromAccountID) REFERENCES Accounts(AccountID),
    FOREIGN KEY (ToAccountID) REFERENCES Accounts(AccountID),
    INDEX idx_date (TransactionDate),
    INDEX idx_status (Status)
);
GO

-- ============================================================================
-- AuditLog Table (VULNERABLE: May contain sensitive data)
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLog')
CREATE TABLE AuditLog (
    LogID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT,
    Action NVARCHAR(255),
    Details NVARCHAR(MAX),  -- VULNERABILITY: Unfiltered data, may contain passwords
    IPAddress NVARCHAR(50),
    Timestamp DATETIME DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    INDEX idx_user (UserID),
    INDEX idx_timestamp (Timestamp)
);
GO

-- ============================================================================
-- Create stored procedures (with vulnerabilities for CTF)
-- ============================================================================

-- Simple authentication procedure (VULNERABLE: No password hashing verification)
CREATE PROCEDURE sp_AuthenticateUser
    @Username NVARCHAR(50),
    @Password NVARCHAR(255)
AS
BEGIN
    SELECT UserID, Username, Email, AccountType
    FROM Users
    WHERE Username = @Username
    -- VULNERABILITY: Password check would be here but is missing in this vulnerable version
    AND IsActive = 1
END
GO

-- Procedure to get user account balances
CREATE PROCEDURE sp_GetUserAccounts
    @UserID INT
AS
BEGIN
    SELECT 
        AccountID,
        AccountNumber,
        AccountType,
        Balance,
        Status
    FROM Accounts
    WHERE UserID = @UserID
    ORDER BY CreatedDate DESC
END
GO

-- Procedure to execute arbitrary queries (VULNERABILITY: SQL Injection ready!)
CREATE PROCEDURE sp_ExecuteQuery
    @Query NVARCHAR(MAX)
AS
BEGIN
    EXEC sp_executesql @Query
END
GO

-- Administrative procedure to export all data
CREATE PROCEDURE sp_ExportAllData
AS
BEGIN
    -- Export Users
    SELECT 'Users' AS TableName
    SELECT * FROM Users
    
    -- Export Accounts  
    SELECT 'Accounts' AS TableName
    SELECT * FROM Accounts
    
    -- Export Transactions
    SELECT 'Transactions' AS TableName
    SELECT * FROM Transactions
    
    -- Export Audit Log
    SELECT 'AuditLog' AS TableName
    SELECT * FROM AuditLog
END
GO

-- ============================================================================
-- Create admin user (for lab purposes)
-- ============================================================================
IF NOT EXISTS (SELECT * FROM Users WHERE Username = 'Administrator')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, FullName, AccountType, IsActive)
    VALUES (
        'Administrator',
        'admin@modernbank.local',
        'admin_password_hash_mock',
        'System Administrator',
        'Admin',
        1
    );
END
GO

-- ============================================================================
-- Populate sample data for testing
-- ============================================================================
DECLARE @AdminUserID INT = (SELECT TOP 1 UserID FROM Users WHERE Username = 'Administrator');
DECLARE @DefaultAccountID INT;

-- Add if sample users don't exist
IF NOT EXISTS (SELECT * FROM Users WHERE Username = 'john_doe')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, AccountType, IsActive)
    VALUES (
        'john_doe',
        'john@modernbank.local',
        'password_hash_mock',
        'John Doe',
        '+1-555-1234',
        'Premium',
        1
    );
    
    INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, AccountType, IsActive)
    VALUES (
        'jane_smith',
        'jane@modernbank.local',
        'password_hash_mock',
        'Jane Smith',
        '+1-555-5678',
        'Standard',
        1
    );
END
GO

-- Insert sample accounts if they don't exist
DECLARE @JohnID INT = (SELECT UserID FROM Users WHERE Username = 'john_doe');
DECLARE @JaneID INT = (SELECT UserID FROM Users WHERE Username = 'jane_smith');

IF @JohnID IS NOT NULL AND NOT EXISTS (SELECT * FROM Accounts WHERE UserID = @JohnID)
BEGIN
    INSERT INTO Accounts (UserID, AccountNumber, AccountType, Balance, Status)
    VALUES 
        (@JohnID, 'CHK-00014521', 'Checking', 12847.50, 'Active'),
        (@JohnID, 'SAV-00017839', 'Savings', 58920.00, 'Active'),
        (@JohnID, 'CC-00089456', 'Credit Card', 3240.17, 'Active');
    
    INSERT INTO Accounts (UserID, AccountNumber, AccountType, Balance, Status)  
    VALUES 
        (@JaneID, 'CHK-00025432', 'Checking', 5432.75, 'Active'),
        (@JaneID, 'SAV-00065789', 'Savings', 25000.00, 'Active');
END
GO

-- Insert sample transactions
DECLARE @JohnAccountID INT = (SELECT TOP 1 AccountID FROM Accounts WHERE UserID = (SELECT UserID FROM Users WHERE Username = 'john_doe') AND AccountType = 'Checking');
DECLARE @JaneAccountID INT = (SELECT TOP 1 AccountID FROM Accounts WHERE UserID = (SELECT UserID FROM Users WHERE Username = 'jane_smith') AND AccountType = 'Checking');

IF @JohnAccountID IS NOT NULL AND NOT EXISTS (SELECT * FROM Transactions)
BEGIN
    INSERT INTO Transactions (FromAccountID, Amount, TransactionType, Description, Category, TransactionDate, Status, ReferenceNumber)
    VALUES
        (@JohnAccountID, 45.99, 'Purchase', 'Amazon Purchase', 'Shopping', DATEADD(DAY, -3, GETDATE()), 'Completed', 'TXN-001-2024'),
        (@JohnAccountID, 3500.00, 'Deposit', 'Salary Deposit', 'Income', DATEADD(DAY, -2, GETDATE()), 'Completed', 'TXN-002-2024'),
        (@JohnAccountID, 127.45, 'Payment', 'Electric Company', 'Utilities', DATEADD(DAY, -1, GETDATE()), 'Completed', 'TXN-003-2024'),
        (@JohnAccountID, 15.99, 'Subscription', 'Netflix Subscription', 'Subscription', GETDATE(), 'Completed', 'TXN-004-2024');
END
GO

-- ============================================================================
-- Create database role for app access (VULNERABILITY: Overprivileged)
-- ============================================================================
CREATE LOGIN bankapp WITH PASSWORD = 'BankApp@2024!Insecure';
GO

IF NOT EXISTS (SELECT * FROM sys.sysusers WHERE name = 'bankapp')
    CREATE USER bankapp FOR LOGIN bankapp;
GO

-- Grant overprivileged access (for CTF purposes - normally dangerous!)
ALTER ROLE db_owner ADD MEMBER bankapp;
GO

-- ============================================================================
-- Create additional vulnerable login for testing
-- ============================================================================
CREATE LOGIN testuser WITH PASSWORD = 'testpass123';
GO

CREATE USER testuser FOR LOGIN testuser;
GO

-- Grant limited access
GRANT SELECT, INSERT, UPDATE ON dbo.Users TO testuser;
GRANT SELECT, INSERT, UPDATE ON dbo.Accounts TO testuser;
GO

-- ============================================================================
-- Print confirmation
-- ============================================================================
PRINT 'Modern Bank Database Schema Created Successfully!';
PRINT '';
PRINT 'Database: ModernBank';
PRINT 'Tables Created:';
PRINT '  - Users';
PRINT '  - Accounts';
PRINT '  - Transactions';
PRINT '  - AuditLog';
PRINT '';
PRINT 'Sample Data Inserted:';
PRINT '  - Administrator user';
PRINT '  - john_doe (Premium)';
PRINT '  - jane_smith (Standard)';
PRINT '  - Sample accounts and transactions';
PRINT '';
PRINT 'Logins Created:';
PRINT '  - bankapp (overprivileged - VULNERABLE)';
PRINT '  - testuser (limited access)';
GO
