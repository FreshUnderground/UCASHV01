# UCASH - Complete User Documentation (English)

## Table of Contents
1. [Introduction](#introduction)
2. [System Overview](#system-overview)
3. [User Roles](#user-roles)
4. [Getting Started](#getting-started)
5. [Administrator Guide](#administrator-guide)
6. [Agent Guide](#agent-guide)
7. [Client Guide](#client-guide)
8. [Features Reference](#features-reference)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Introduction

UCASH is a comprehensive modern money transfer and financial management application designed for multi-currency operations (USD/CDF). The system supports three main user types: Administrators, Agents, and Clients, each with specific roles and permissions.

### Key Features
- **Multi-currency support** (USD/CDF)
- **Real-time synchronization** between devices
- **Comprehensive reporting** and analytics
- **Virtual transaction management**
- **Personnel management system**
- **Multi-language support** (English/French)
- **Offline capability** with automatic sync
- **Advanced security** with role-based access

---

## System Overview

### Architecture
UCASH operates on a client-server architecture with:
- **Local SQLite database** for offline operations
- **MySQL server** for centralized data storage
- **Real-time synchronization** between local and server databases
- **RESTful API** for data exchange

### Currency System
- **Primary Currency**: USD (United States Dollar)
- **Secondary Currency**: CDF (Congolese Franc)
- **Cash Operations**: Always in USD
- **Virtual Transactions**: Support both USD and CDF
- **Automatic Conversion**: Based on current exchange rates

---

## User Roles

### 1. Administrator (ADMIN)
**Full system access with capabilities to:**
- Manage shops, agents, and clients
- Configure rates and commissions
- Access all reports and analytics
- Manage system settings
- Handle deletions and validations
- Oversee personnel management
- Monitor system synchronization

### 2. Agent (AGENT)
**Shop-level operations with access to:**
- Process transactions (deposits, withdrawals, transfers)
- Manage virtual transactions
- Handle client validations
- Generate shop reports
- Manage shop personnel
- Process inter-shop debts
- Handle daily closures

### 3. Client (CLIENT)
**Limited access for personal account management:**
- View account balance and history
- Request transactions
- View personal transaction reports
- Update personal information

---

## Getting Started

### System Requirements
- **Operating System**: Windows, Android, iOS
- **Internet Connection**: Required for synchronization
- **Storage**: Minimum 100MB free space
- **RAM**: Minimum 2GB recommended

### First Login
1. **Launch the application**
2. **Select user type**: Admin, Agent, or Client
3. **Enter credentials**:
   - Default Admin: `admin` / `admin123`
   - Agent credentials provided by administrator
   - Client credentials provided by agent
4. **Language selection**: Choose English or French
5. **Initial synchronization** will occur automatically

### Navigation
- **Desktop**: Use sidebar navigation
- **Mobile**: Use bottom navigation or drawer menu
- **Tablet**: Responsive layout adapts automatically

---

## Administrator Guide

### Dashboard Overview
The admin dashboard provides:
- **System statistics** and key metrics
- **Recent activity** overview
- **Synchronization status**
- **Quick access** to main functions

### Main Menu Sections

#### 1. Dashboard
- System overview and statistics
- Recent transactions summary
- Active users and shops
- System health indicators

#### 2. Expenses Management
- Track operational expenses
- Categorize spending
- Generate expense reports
- Budget monitoring

#### 3. Shops Management
**Create New Shop:**
1. Navigate to **Shops** section
2. Click **Add Shop** button
3. Fill required information:
   - Shop name and designation
   - Location and address
   - Contact information
   - Initial capital
4. Save and assign agents

**Manage Existing Shops:**
- View shop details and statistics
- Edit shop information
- Manage shop capital
- Assign/reassign agents
- Monitor shop performance

#### 4. Agents Management
**Add New Agent:**
1. Go to **Agents** section
2. Click **Create Agent**
3. Enter agent details:
   - Personal information
   - Login credentials
   - Shop assignment
   - Role and permissions
4. Generate automatic matricule
5. Save agent profile

**Agent Operations:**
- View agent performance
- Edit agent information
- Manage agent permissions
- Handle agent transfers
- Monitor agent activities

#### 5. Administrators Management
- Create additional admin accounts
- Manage admin permissions
- Monitor admin activities
- System access control

#### 6. VIRTUEL (Virtual Transactions)
**Overview Tab:**
- Daily virtual transaction statistics
- Currency breakdown (USD/CDF)
- Operator performance metrics
- Cash availability tracking

**En Attente (Pending) Tab:**
- View pending virtual transactions
- Filter by date, amount, currency
- Process bulk validations
- Export pending transactions

**Servis (Served) Tab:**
- Completed virtual transactions
- Service statistics
- Performance analytics
- Revenue tracking

**Liste Transactions Tab:**
- Complete transaction listing
- Advanced filtering options
- SIM-based filtering
- PDF export functionality

**Frais (Fees) Tab:**
- Fee calculations and tracking
- Commission breakdowns
- Revenue from fees
- Fee structure management

**Clôture par SIM Tab:**
- SIM-based closure reports
- Daily/period closures
- Cash reconciliation
- Virtual balance management

#### 7. Partners Management
- Manage business partners
- Partner transaction tracking
- Commission structures
- Partnership agreements

#### 8. Rates and Commissions
**Exchange Rates:**
- USD/CDF exchange rates
- Rate history tracking
- Automatic rate updates
- Manual rate adjustments

**Commission Structure:**
- Transaction fees setup
- Percentage-based commissions
- Fixed fee structures
- Shop-specific rates

#### 9. Reports
**Financial Reports:**
- Daily/monthly/yearly summaries
- Revenue and profit analysis
- Transaction volume reports
- Currency-specific reports

**Operational Reports:**
- Agent performance reports
- Shop activity summaries
- System usage statistics
- Error and sync reports

#### 10. Inter-shop Debts
- Monitor debts between shops
- Debt settlement tracking
- Payment schedules
- Debt aging reports

#### 11. Configuration
**System Settings:**
- Application preferences
- Security settings
- Backup configurations
- Integration settings

**User Management:**
- User role definitions
- Permission matrices
- Access control settings
- Session management

#### 12. Deletions
**Deletion Requests:**
- Review deletion requests from agents
- Approve/reject deletions
- Maintain deletion audit trail
- Bulk deletion processing

**Validation Workflow:**
- Two-step validation process
- Admin approval required
- Agent confirmation needed
- Complete audit logging

#### 13. Admin Validations
- Final approval for critical operations
- System-wide validation controls
- Override capabilities
- Emergency procedures

#### 14. Trash/Recycle Bin
- Recover deleted items
- Permanent deletion management
- Data retention policies
- Cleanup procedures

#### 15. Initialization
- System setup and configuration
- Initial data loading
- Default settings establishment
- First-time setup wizard

#### 16. Personnel Management
**Employee Management:**
- Add new employees
- Manage employee records
- Track employment history
- Handle employee status changes

**Salary Management:**
- Process monthly salaries
- Handle salary adjustments
- Manage bonuses and deductions
- Generate payroll reports

**Advances and Deductions:**
- Process salary advances
- Manage loan deductions
- Track repayment schedules
- Handle special deductions

### Advanced Features

#### Synchronization Management
- **Monitor sync status** across all devices
- **Force synchronization** when needed
- **Resolve sync conflicts** automatically
- **Backup and restore** data

#### Multi-language Support
- **Switch languages** dynamically
- **Localized content** for all features
- **Regional formatting** for dates and numbers
- **Cultural adaptations** for business rules

#### Security Features
- **Role-based access control**
- **Session management**
- **Audit logging**
- **Data encryption**

---

## Agent Guide

### Dashboard Overview
The agent dashboard provides:
- **Shop statistics** and performance metrics
- **Daily transaction summary**
- **Pending validations** count
- **Quick action buttons**

### Main Menu Sections

#### 1. Operations
**Transaction Processing:**
- **Deposits**: Accept cash deposits from clients
- **Withdrawals**: Process cash withdrawals
- **Transfers**: Handle money transfers between accounts
- **Currency Exchange**: Convert between USD and CDF

**Daily Operations:**
1. **Start of Day**: Check cash balance and system sync
2. **Process Transactions**: Handle client requests
3. **Record Operations**: Ensure all transactions are logged
4. **End of Day**: Perform daily closure

#### 2. Validations
**Pending Transactions:**
- Review transactions awaiting validation
- Verify transaction details
- Approve or reject transactions
- Handle validation exceptions

**Validation Process:**
1. **Review Details**: Check transaction information
2. **Verify Identity**: Confirm client identity
3. **Check Balances**: Ensure sufficient funds
4. **Process Validation**: Approve or reject
5. **Notify Client**: Send confirmation

#### 3. Reports
**Daily Reports:**
- Transaction summaries
- Cash flow reports
- Commission earnings
- Error reports

**Periodic Reports:**
- Weekly performance summaries
- Monthly transaction volumes
- Quarterly analysis
- Annual reviews

#### 4. FLOT (Float Management)
**Float Operations:**
- Manage shop cash float
- Request float transfers
- Handle float reconciliation
- Monitor float levels

**Float Requests:**
1. **Check Current Float**: Review available cash
2. **Calculate Needs**: Determine required amount
3. **Submit Request**: Request float transfer
4. **Receive Confirmation**: Wait for approval
5. **Update Records**: Record float receipt

#### 5. Fees Management
**Fee Tracking:**
- Monitor collected fees
- Track commission earnings
- Generate fee reports
- Handle fee disputes

#### 6. VIRTUEL (Virtual Transactions)
**Virtual Transaction Management:**
- Process mobile money transactions
- Handle virtual account operations
- Manage SIM-based transactions
- Monitor virtual balances

**Key Features:**
- **Multi-SIM Support**: Handle multiple SIM cards
- **Real-time Processing**: Instant transaction processing
- **Balance Management**: Track virtual and cash balances
- **Reconciliation**: Daily balance reconciliation

#### 7. Inter-shop Debts
**Debt Management:**
- Track debts with other shops
- Process debt payments
- Monitor debt aging
- Generate debt reports

#### 8. Triangular Settlements
**Settlement Process:**
- Handle three-party settlements
- Process complex transactions
- Manage settlement schedules
- Track settlement status

#### 9. Deletions
**Deletion Requests:**
- Request transaction deletions
- Provide deletion justification
- Track deletion status
- Handle deletion approvals

### Daily Workflows

#### Morning Routine
1. **Login and Sync**: Start application and sync data
2. **Check Notifications**: Review overnight activities
3. **Verify Cash Balance**: Confirm opening balance
4. **Review Pending Items**: Check validation queue
5. **Prepare for Operations**: Set up for daily transactions

#### Transaction Processing
1. **Client Identification**: Verify client identity
2. **Transaction Details**: Record transaction information
3. **Amount Verification**: Confirm transaction amounts
4. **Processing**: Execute the transaction
5. **Confirmation**: Provide transaction receipt
6. **Record Keeping**: Ensure proper documentation

#### End of Day Routine
1. **Transaction Review**: Verify all transactions processed
2. **Cash Reconciliation**: Balance cash drawer
3. **Generate Reports**: Create daily summaries
4. **System Sync**: Ensure all data synchronized
5. **Secure Cash**: Follow security procedures

### Best Practices

#### Security
- **Always verify client identity** before processing
- **Keep cash secure** and properly counted
- **Log out when away** from workstation
- **Report suspicious activities** immediately

#### Customer Service
- **Be professional** and courteous
- **Explain procedures** clearly to clients
- **Handle complaints** promptly and fairly
- **Maintain confidentiality** of client information

#### Record Keeping
- **Document all transactions** completely
- **Keep receipts organized** and accessible
- **Maintain accurate records** of all activities
- **Report discrepancies** immediately

---

## Client Guide

### Account Access
**Login Process:**
1. **Select Client Login** from main screen
2. **Enter Username**: Provided by your agent
3. **Enter Password**: Set during account creation
4. **Select Language**: Choose preferred language
5. **Access Dashboard**: View account overview

### Dashboard Features
- **Account Balance**: Current balance in USD/CDF
- **Recent Transactions**: Last 10 transactions
- **Account Status**: Active/inactive status
- **Quick Actions**: Common operations

### Available Services

#### 1. Account Information
**View Details:**
- Personal information
- Contact details
- Account status
- Account limits

**Update Information:**
- Change contact details
- Update address
- Modify preferences
- Change password

#### 2. Transaction History
**View Transactions:**
- Complete transaction history
- Filter by date range
- Search by transaction type
- Export transaction reports

**Transaction Details:**
- Transaction ID and reference
- Date and time
- Amount and currency
- Transaction type
- Status and confirmations

#### 3. Balance Inquiry
**Current Balance:**
- Available balance
- Pending transactions
- Reserved amounts
- Total balance

**Balance History:**
- Daily balance changes
- Monthly summaries
- Balance trends
- Historical data

#### 4. Transaction Requests
**Request Services:**
- Money transfers
- Cash withdrawals
- Account deposits
- Currency exchange

**Request Process:**
1. **Select Service**: Choose transaction type
2. **Enter Details**: Provide transaction information
3. **Confirm Request**: Review and confirm
4. **Wait for Processing**: Agent will handle request
5. **Receive Confirmation**: Get transaction receipt

### Mobile Features
- **Responsive Design**: Works on all devices
- **Touch-friendly Interface**: Easy navigation
- **Offline Viewing**: Access cached information
- **Push Notifications**: Transaction alerts

---

## Features Reference

### Multi-Currency System
**Supported Currencies:**
- **USD (United States Dollar)**: Primary currency
- **CDF (Congolese Franc)**: Secondary currency

**Currency Rules:**
- **Cash Operations**: Always processed in USD
- **Virtual Transactions**: Support both USD and CDF
- **Exchange Rates**: Updated regularly
- **Conversion**: Automatic based on current rates

### Synchronization System
**Automatic Sync:**
- **Real-time**: Immediate sync for critical operations
- **Scheduled**: Regular sync every few minutes
- **Manual**: User-initiated sync when needed
- **Conflict Resolution**: Automatic handling of data conflicts

**Sync Features:**
- **Offline Capability**: Work without internet connection
- **Data Integrity**: Ensure data consistency
- **Error Handling**: Robust error recovery
- **Progress Tracking**: Monitor sync progress

### Reporting System
**Report Types:**
- **Financial Reports**: Revenue, profit, expenses
- **Operational Reports**: Transactions, activities
- **Performance Reports**: Agent and shop performance
- **Compliance Reports**: Regulatory requirements

**Report Features:**
- **Multiple Formats**: PDF, Excel, CSV
- **Customizable**: Filter and customize reports
- **Scheduled**: Automatic report generation
- **Distribution**: Email and share reports

### Security Features
**Authentication:**
- **Multi-factor Authentication**: Enhanced security
- **Role-based Access**: Appropriate permissions
- **Session Management**: Secure session handling
- **Password Policies**: Strong password requirements

**Data Protection:**
- **Encryption**: Data encrypted in transit and at rest
- **Audit Logging**: Complete activity tracking
- **Backup Systems**: Regular data backups
- **Access Controls**: Strict access limitations

---

## Troubleshooting

### Common Issues

#### Login Problems
**Issue**: Cannot login to the system
**Solutions:**
1. **Check Credentials**: Verify username and password
2. **Check Internet**: Ensure stable internet connection
3. **Clear Cache**: Clear application cache and data
4. **Contact Support**: If problem persists

#### Synchronization Issues
**Issue**: Data not syncing properly
**Solutions:**
1. **Check Connection**: Verify internet connectivity
2. **Manual Sync**: Force manual synchronization
3. **Restart App**: Close and restart application
4. **Check Server Status**: Verify server availability

#### Transaction Errors
**Issue**: Transaction failed or incomplete
**Solutions:**
1. **Check Balance**: Verify sufficient funds
2. **Verify Details**: Confirm transaction information
3. **Retry Transaction**: Attempt transaction again
4. **Contact Agent**: Seek assistance if needed

#### Performance Issues
**Issue**: Application running slowly
**Solutions:**
1. **Close Other Apps**: Free up device memory
2. **Clear Cache**: Clear application cache
3. **Update App**: Install latest version
4. **Restart Device**: Reboot device if necessary

### Error Messages

#### "Network Connection Error"
- **Cause**: No internet connection or poor connectivity
- **Solution**: Check internet connection and retry

#### "Invalid Credentials"
- **Cause**: Incorrect username or password
- **Solution**: Verify credentials or reset password

#### "Transaction Limit Exceeded"
- **Cause**: Transaction amount exceeds allowed limit
- **Solution**: Reduce amount or contact administrator

#### "Insufficient Funds"
- **Cause**: Account balance too low for transaction
- **Solution**: Deposit funds or reduce transaction amount

### Getting Help
**Support Channels:**
- **In-App Help**: Built-in help system
- **User Manual**: This documentation
- **Technical Support**: Contact system administrator
- **Training**: Request additional training

---

## FAQ

### General Questions

**Q: What is UCASH?**
A: UCASH is a comprehensive money transfer and financial management application supporting multi-currency operations with real-time synchronization.

**Q: What currencies are supported?**
A: UCASH supports USD (United States Dollar) and CDF (Congolese Franc) with automatic conversion capabilities.

**Q: Can I use UCASH offline?**
A: Yes, UCASH has offline capabilities. Data will sync automatically when internet connection is restored.

**Q: How do I change the language?**
A: Use the language selector in the top menu bar to switch between English and French.

### Account Questions

**Q: How do I reset my password?**
A: Contact your administrator or agent to reset your password. They can provide you with new credentials.

**Q: Why is my account locked?**
A: Accounts may be locked due to security reasons or administrative actions. Contact your administrator for assistance.

**Q: How do I update my personal information?**
A: Agents and clients can update certain information through their profile settings. Some changes may require administrator approval.

### Transaction Questions

**Q: How long do transactions take to process?**
A: Most transactions are processed immediately. Some may require validation and can take a few minutes to complete.

**Q: What are the transaction limits?**
A: Transaction limits vary by user type and account settings. Contact your administrator for specific limit information.

**Q: Can I cancel a transaction?**
A: Pending transactions may be cancelled. Completed transactions require special deletion procedures through proper channels.

**Q: How do I get a transaction receipt?**
A: Transaction receipts are automatically generated and can be viewed in your transaction history or printed if needed.

### Technical Questions

**Q: What devices are supported?**
A: UCASH supports Windows computers, Android tablets and phones, and iOS devices.

**Q: How often does the system sync?**
A: The system syncs automatically every few minutes and immediately for critical operations.

**Q: What happens if there's a sync conflict?**
A: The system automatically resolves most conflicts. Complex conflicts are flagged for manual resolution.

**Q: How is my data protected?**
A: UCASH uses encryption, secure authentication, and regular backups to protect your data.

### Business Questions

**Q: How are exchange rates determined?**
A: Exchange rates are set by administrators and updated regularly based on market conditions.

**Q: What fees apply to transactions?**
A: Fees vary by transaction type and amount. Check with your agent or administrator for current fee schedules.

**Q: How do I become an agent?**
A: Contact the system administrator to inquire about agent opportunities and requirements.

**Q: Can I have multiple accounts?**
A: Account policies vary by organization. Check with your administrator about multiple account options.

---

## Contact Information

For additional support or questions not covered in this documentation:

**Technical Support:**
- Contact your system administrator
- Use in-app help features
- Refer to error message guides

**Training:**
- Request additional training sessions
- Access online tutorials
- Practice with demo accounts

**Updates:**
- Check for application updates regularly
- Review release notes for new features
- Participate in training for new functionality

---

*This documentation is regularly updated. Please check for the latest version to ensure you have current information.*

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Language:** English
