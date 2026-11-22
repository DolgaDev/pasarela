// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Counter {
    /// @notice Valor máximo que puede alcanzar `number` con increment().
    uint256 public constant MAX = 100;

    uint256 public number;
    address public immutable owner;

    event NumberSet(address indexed by, uint256 oldValue, uint256 newValue);

    error NotOwner(address caller);
    error MaxReached(uint256 current);

    constructor() {
        owner = msg.sender;
    }

    function setNumber(uint256 newNumber) public {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        uint256 oldValue = number;
        number = newNumber;
        emit NumberSet(msg.sender, oldValue, newNumber);
    }

    function increment() public {
        uint256 current = number; // una sola lectura de storage (SLOAD)
        if (current >= MAX) revert MaxReached(current);
        uint256 newValue = current + 1;
        number = newValue;
        emit NumberSet(msg.sender, current, newValue);
    }
}
