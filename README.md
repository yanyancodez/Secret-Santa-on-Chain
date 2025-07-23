# 🎅 Secret Santa on Chain

A decentralized Secret Santa gift exchange system built on the Stacks blockchain using Clarity smart contracts.

## 🎁 Features

- **Random Pairing**: Automated participant pairing using blockchain randomness
- **STX Gift Values**: Set minimum gift amounts and contribute STX tokens
- **Privacy Preserved**: Recipients only revealed after gifts are sent
- **Emergency Recovery**: Participants can withdraw funds if gifts aren't exchanged
- **Round-based Games**: Multiple Secret Santa rounds supported

## 🚀 How It Works

### 1. Game Initialization 🎯
The contract owner initializes a new Secret Santa round with:
- Registration deadline
- Gift reveal deadline  
- Minimum gift amount in STX

### 2. Registration Phase 📝
Participants register by:
- Calling `register` with their desired gift amount
- Transferring STX tokens to the contract as collateral
- Must register before the deadline

### 3. Pairing Phase 🔗
After registration closes:
- Owner calls `generate-pairings` to randomly assign recipients
- Each participant gets exactly one recipient
- Pairings form a complete circle

### 4. Gift Exchange 🎁
Participants send gifts by:
- Calling `send-gift` with their assigned recipient and message
- Must send to their assigned recipient only
- Gifts are recorded but not immediately transferred

### 5. Reveal Phase 🔍
Recipients reveal their gifts by:
- Calling `reveal-gift` to claim their STX tokens
- Gift information and sender identity are revealed
- STX tokens are transferred to the recipient

### 6. Emergency Recovery ⚠️
If the reveal deadline passes:
- Participants who didn't send gifts can withdraw their STX
- Prevents loss of funds from incomplete exchanges

## 📋 Contract Functions

### Public Functions

#### `initialize-game`
```clarity
(initialize-game reg-deadline reveal-deadline min-amount)
```
Initialize a new Secret Santa round (owner only).

#### `register`
```clarity
(register gift-amount)
```
Register to participate with specified gift amount.

#### `close-registration`
```clarity
(close-registration)
```
Close registration period (owner only).

#### `generate-pairings`
```clarity
(generate-pairings)
```
Generate random recipient assignments (owner only).

#### `send-gift`
```clarity
(send-gift recipient message)
```
Send gift to assigned recipient with message.

#### `reveal-gift`
```clarity
(reveal-gift)
```
Reveal and claim your received gift.

#### `emergency-withdraw`
```clarity
(emergency-withdraw)
```
Withdraw STX if you didn't send a gift after deadline.

#### `end-game`
```clarity
(end-game)
```
End the current round (owner only).

### Read-Only Functions

#### `get-participant-info`
Get participant registration details.

#### `get-gift-info`
Get gift details for a recipient.

#### `get-game-status`
Get current game state and deadlines.

#### `get-my-recipient`
Get your assigned recipient (if paired).

#### `is-registered`
Check if an address is registered for current round.

#### `can-reveal-gift`
Check if a gift can be revealed.

#### `get-contract-balance`
Get total STX held by contract.

## 🔧 Usage Example

```bash
# Initialize game (owner)
clarinet console
>> (contract-call? .Secret-Santa-on-Chain initialize-game u1000 u2000 u1000000)

# Register participants
>> (contract-call? .Secret-Santa-on-Chain register u1000000)

# Close registration (owner)
>> (contract-call? .Secret-Santa-on-Chain close-registration)

# Generate pairings (owner)  
>> (contract-call? .Secret-Santa-on-Chain generate-pairings)

# Send gift
>> (contract-call? .Secret-Santa-on-Chain send-gift 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "Happy Holidays!")

# Reveal gift
>> (contract-call? .Secret-Santa-on-Chain reveal-gift)
```

## 🛡️ Security Features

- **Access Control**: Owner-only administrative functions
- **Input Validation**: Proper deadline and amount checks
- **Fund Safety**: Emergency withdrawal mechanism
- **Round Isolation**: Each game round maintains separate state

## ⚡ Requirements

- Clarinet CLI
- Stacks blockchain testnet/mainnet access
- STX tokens for participation

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 📄 License

MIT License - feel free to use and modify for your Secret Santa needs! 🎄
