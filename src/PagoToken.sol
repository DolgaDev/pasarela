// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Token de pagos con 6 decimales. El owner puede acuñar, pero nunca por encima de `cap()`.
/// @dev Todos los montos (initialSupply, maxSupply, amount) van en unidades mínimas: 1 token = 10**6.
contract PagoToken is ERC20, ERC20Capped, ERC20Permit, Ownable {
    constructor(address initialOwner, uint256 initialSupply, uint256 maxSupply)
        ERC20("DolgaToken", "USDG")
        ERC20Capped(maxSupply)
        ERC20Permit("DolgaToken")
        Ownable(initialOwner)
    {
        // El tope también aplica a este mint: si initialSupply > maxSupply, el deploy revierte.
        _mint(initialOwner, initialSupply);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
