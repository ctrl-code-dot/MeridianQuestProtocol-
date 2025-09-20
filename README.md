# Meridian Quest Protocol

## Overview

Meridian Quest Protocol is a sophisticated decentralized task completion and reward system built on the Stacks blockchain using Clarity smart contracts. The protocol enables clients to post quests with milestone-based compensation, secure escrow mechanisms, and comprehensive dispute resolution.

## Key Features

### **Quest Management System**
- **Quest Initialization**: Clients can create detailed quests with specific executors and milestone structures
- **Milestone Tracking**: Five-stage objective system with individual reward allocations
- **Status Management**: Comprehensive quest lifecycle from posted → active → completed

### **Secure Escrow Treasury**
- **Fund Security**: Client funds are locked in smart contract escrow until quest completion
- **Partial Funding**: Flexible funding system allowing incremental escrow deposits
- **Automatic Release**: Compensation automatically available upon milestone completion

### **Dispute Resolution Framework**
- **Stakeholder Protection**: Both clients and executors can initiate disputes
- **Admin Arbitration**: Protocol admin can issue binding resolutions
- **Flexible Settlements**: Customizable refund/reward percentages based on dispute outcomes

### **Security & Validation**
- **Address Validation**: Prevents conflicts of interest in executor assignment
- **Reward Verification**: Ensures milestone rewards sum to total compensation
- **Access Control**: Role-based permissions for all protocol functions

## Smart Contract Architecture

### Core Data Structures

#### Quest Registry
```clarity
quest-registry: {
    executor-address: principal,
    client-address: principal,
    total-compensation: uint,
    quest-status: uint,
    initiation-block: uint,
    completion-deadline: uint,
    dispute-window: uint,
    milestone-objectives: (list 5 milestone-data)
}
```

#### Escrow Treasury
```clarity
escrow-treasury: {
    secured-funds: uint
}
```

#### Protocol Disputes
```clarity
protocol-disputes: {
    dispute-narrative: (string-utf8 200),
    dispute-initiator: principal,
    admin-resolution: (optional (string-utf8 200))
}
```

### Quest Status Flow
1. **Posted** (u0) - Quest created, awaiting funding
2. **Active** (u1) - Fully funded and in progress
3. **Completed** (u2) - All milestones achieved
4. **Cancelled** (u3) - Terminated before completion
5. **Disputed** (u4) - Under admin review

## Core Functions

### Client Functions
- `initialize-quest()` - Create new quest with executor and milestones
- `fund-quest-escrow()` - Add funds to quest escrow treasury
- `release-compensation()` - Release payment upon quest completion
- `terminate-quest()` - Cancel unfunded quest and retrieve funds

### Executor Functions
- `achieve-milestone()` - Mark individual milestone as completed
- Quest progression tracking through milestone completion

### Administrative Functions
- `initiate-protocol-dispute()` - File dispute for quest resolution
- `issue-admin-resolution()` - Provide binding dispute resolution

### Read-Only Functions
- `get-quest-details()` - Retrieve complete quest information
- `get-secured-funds()` - View escrow treasury balance
- `get-dispute-details()` - Access dispute information

## Usage Examples

### Creating a Quest
```clarity
(initialize-quest 
    u1                    ;; quest-id
    'ST1EXECUTOR-ADDRESS  ;; executor
    u1000000             ;; total compensation (1 STX)
    u1000                ;; execution duration (blocks)
    milestone-list       ;; 5 milestone objectives
)
```

### Funding Quest Escrow
```clarity
(fund-quest-escrow u1 u1000000) ;; Fund 1 STX to quest #1
```

### Completing Milestones
```clarity
(achieve-milestone u1 u0) ;; Complete first milestone of quest #1
```

## Security Considerations

- **Executor Validation**: Prevents self-assignment and admin conflicts
- **Milestone Integrity**: Validates reward distribution matches total compensation
- **Time-based Controls**: Dispute windows and completion deadlines
- **Access Controls**: Function-level permission enforcement

## Error Handling

The protocol implements comprehensive error handling with specific error codes:
- `ERROR_UNAUTHORIZED_EXECUTOR` (u100)
- `ERROR_INVALID_QUEST_STATUS` (u101) 
- `ERROR_INSUFFICIENT_REWARD` (u102)
- `ERROR_QUEST_ALREADY_EXISTS` (u103)
- `ERROR_QUEST_NOT_FOUND` (u104)
- `ERROR_INVALID_MILESTONE_INDEX` (u105)
- `ERROR_INVALID_INPUT` (u106)
- `ERROR_INVALID_EXECUTOR_ADDRESS` (u107)
- `ERROR_INVALID_MILESTONE_DATA` (u108)

## Development & Deployment

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity development environment
- STX tokens for gas and testing

### Testing Strategy
- Unit testing for all public functions
- Integration testing for quest lifecycle
- Security testing for edge cases and attack vectors
- Gas optimization testing

### Deployment Checklist
- [ ] Contract compilation verification
- [ ] Comprehensive test suite execution
- [ ] Security audit completion
- [ ] Gas cost optimization
- [ ] Documentation review

## Contributing

We welcome contributions to improve the Meridian Quest Protocol. Please follow standard development practices:

1. Fork the repository
2. Create feature branches
3. Implement comprehensive tests
4. Submit pull requests with detailed descriptions
