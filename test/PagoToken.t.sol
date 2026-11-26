// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {PagoToken} from "../src/PagoToken.sol";

contract PagoTokenTest is Test {
    // Mismo evento que emite ERC20; se declara acá para poder usarlo con vm.expectEmit.
    event Transfer(address indexed from, address indexed to, uint256 value);

    uint256 constant INITIAL = 1_000_000e6; // 1M USDG
    uint256 constant CAP = 10_000_000e6; // 10M USDG

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    PagoToken token;
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    function setUp() public {
        token = new PagoToken(owner, INITIAL, CAP);
    }

    // ---------------------------------------------------------------
    // Básicos (arranque de la consigna, ajustado al constructor con cap)
    // ---------------------------------------------------------------

    function test_InitialSupplyGoesToOwner() public view {
        assertEq(token.balanceOf(owner), INITIAL);
        assertEq(token.totalSupply(), INITIAL);
        assertEq(token.decimals(), 6);
        assertEq(token.name(), "DolgaToken");
        assertEq(token.symbol(), "USDG");
        assertEq(token.owner(), owner);
    }

    function test_ApproveAndTransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 50e6);
        vm.prank(alice);
        token.transferFrom(owner, alice, 30e6);
        assertEq(token.allowance(owner, alice), 20e6);
        assertEq(token.balanceOf(alice), 30e6);
    }

    function test_MintRevertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, 1);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, token.balanceOf(owner));
        vm.prank(owner);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), INITIAL - amount);
    }

    // ---------------------------------------------------------------
    // 1. Evento Transfer con vm.expectEmit
    // ---------------------------------------------------------------

    function test_TransferEmitsEvent() public {
        // Chequea topic1 (from), topic2 (to) y data (value); no hay topic3.
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(owner, alice, 100e6);

        vm.prank(owner);
        token.transfer(alice, 100e6);
    }

    function test_MintEmitsTransferFromZero() public {
        // En ERC20, mintear se registra como Transfer desde address(0).
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(0), alice, 5e6);

        vm.prank(owner);
        token.mint(alice, 5e6);
    }

    // ---------------------------------------------------------------
    // 2. Transferencia por encima del saldo revierte
    // ---------------------------------------------------------------

    function test_TransferRevertsIfInsufficientBalance() public {
        // alice no tiene saldo: ERC20InsufficientBalance(sender, balance, needed)
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1e6));
        token.transfer(owner, 1e6);
    }

    function test_TransferRevertsIfAboveOwnerBalance() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, INITIAL, INITIAL + 1)
        );
        token.transfer(alice, INITIAL + 1);
    }

    // ---------------------------------------------------------------
    // 3. Permit (EIP-2612) con vm.sign
    // ---------------------------------------------------------------

    function _signPermit(uint256 privateKey, address signer, address spender, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, signer, spender, value, token.nonces(signer), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(privateKey, digest);
    }

    function test_Permit() public {
        (address signer, uint256 signerKey) = makeAddrAndKey("signer");
        uint256 value = 250e6;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(signerKey, signer, alice, value, deadline);

        // Cualquiera puede enviar la firma (acá lo hace alice, que paga el gas).
        vm.prank(alice);
        token.permit(signer, alice, value, deadline, v, r, s);

        assertEq(token.allowance(signer, alice), value);
        assertEq(token.nonces(signer), 1);
    }

    function test_PermitRevertsIfExpired() public {
        (address signer, uint256 signerKey) = makeAddrAndKey("signer");
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(signerKey, signer, alice, 250e6, deadline);

        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, deadline));
        token.permit(signer, alice, 250e6, deadline, v, r, s);
    }

    function test_PermitRevertsOnReplay() public {
        (address signer, uint256 signerKey) = makeAddrAndKey("signer");
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(signerKey, signer, alice, 250e6, deadline);

        token.permit(signer, alice, 250e6, deadline, v, r, s);

        // Reusar la misma firma falla: el nonce ya avanzó, así que se recupera otra dirección.
        vm.expectRevert();
        token.permit(signer, alice, 250e6, deadline, v, r, s);
    }

    // ---------------------------------------------------------------
    // Tope de emisión (ERC20Capped)
    // ---------------------------------------------------------------

    function test_OwnerCanMintUpToCap() public {
        vm.prank(owner);
        token.mint(alice, CAP - INITIAL);
        assertEq(token.totalSupply(), CAP);
        assertEq(token.cap(), CAP);
    }

    function test_MintRevertsIfExceedsCap() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        token.mint(alice, CAP - INITIAL + 1);
    }

    function test_DeployRevertsIfInitialSupplyExceedsCap() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        new PagoToken(owner, CAP + 1, CAP);
    }
}
