// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {PaymentReceipt} from "../src/PaymentReceipt.sol";

/// @dev Contrato que acepta NFTs (implementa onERC721Received).
contract ReceiverOk is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev Contrato que NO implementa onERC721Received: _safeMint debe rechazarlo.
contract ReceiverNone {}

contract PaymentReceiptTest is Test {
    // Mismos eventos que emite el contrato; se declaran acá para usarlos con vm.expectEmit.
    event ReceiptIssued(uint256 indexed tokenId, address indexed to, string uri);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    PaymentReceipt receipt;
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    // CID del JSON de metadata subido a Pinata (metadata/receipt-0.json).
    string constant URI = "ipfs://bafkreihxxynzd62fs6yn3dzal76q3hx3qrwsltp36gicjwu2vyavxz3ez4";

    function setUp() public {
        receipt = new PaymentReceipt(owner);
    }

    // ---------------------------------------------------------------
    // Base de la consigna
    // ---------------------------------------------------------------

    function test_OwnerMintsReceipt() public {
        vm.prank(owner);
        uint256 id = receipt.mintReceipt(alice, URI);
        assertEq(id, 0);
        assertEq(receipt.ownerOf(0), alice);
        assertEq(receipt.tokenURI(0), URI);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        receipt.mintReceipt(alice, URI);
    }

    function testFuzz_IdsAreSequential(uint8 n) public {
        vm.startPrank(owner);
        for (uint256 i = 0; i < n; i++) {
            assertEq(receipt.mintReceipt(alice, URI), i);
        }
        vm.stopPrank();
        assertEq(receipt.balanceOf(alice), n);
    }

    // ---------------------------------------------------------------
    // Tests propios
    // ---------------------------------------------------------------

    function test_Metadata() public view {
        assertEq(receipt.name(), "Payment Receipt");
        assertEq(receipt.symbol(), "RCPT");
        assertEq(receipt.owner(), owner);
    }

    /// El evento ReceiptIssued se emite con tokenId, destinatario y URI correctos.
    function test_EmitsReceiptIssued() public {
        // topic1 = tokenId, topic2 = to (indexados); data = uri.
        vm.expectEmit(true, true, false, true, address(receipt));
        emit ReceiptIssued(0, alice, URI);

        vm.prank(owner);
        receipt.mintReceipt(alice, URI);
    }

    /// El mint también emite el Transfer estándar de ERC-721 desde address(0).
    function test_EmitsTransferFromZero() public {
        vm.expectEmit(true, true, true, false, address(receipt));
        emit Transfer(address(0), alice, 0);

        vm.prank(owner);
        receipt.mintReceipt(alice, URI);
    }

    /// ownerOf de un id que no existe revierte con ERC721NonexistentToken.
    function test_RevertWhen_OwnerOfNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 42));
        receipt.ownerOf(42);
    }

    /// tokenURI de un id que no existe también revierte.
    function test_RevertWhen_TokenURINonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
        receipt.tokenURI(0);
    }

    /// Cada recibo guarda su propia URI.
    function test_EachReceiptKeepsItsURI() public {
        vm.startPrank(owner);
        receipt.mintReceipt(alice, "ipfs://cid-a");
        receipt.mintReceipt(bob, "ipfs://cid-b");
        vm.stopPrank();

        assertEq(receipt.tokenURI(0), "ipfs://cid-a");
        assertEq(receipt.tokenURI(1), "ipfs://cid-b");
        assertEq(receipt.ownerOf(1), bob);
    }

    /// _safeMint rechaza contratos que no implementan onERC721Received.
    function test_RevertWhen_MintToNonReceiverContract() public {
        ReceiverNone bad = new ReceiverNone();
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(bad)));
        vm.prank(owner);
        receipt.mintReceipt(address(bad), URI);
    }

    /// _safeMint acepta contratos que sí implementan onERC721Received.
    function test_MintToReceiverContract() public {
        ReceiverOk good = new ReceiverOk();
        vm.prank(owner);
        receipt.mintReceipt(address(good), URI);
        assertEq(receipt.ownerOf(0), address(good));
    }

    /// No se puede mintear a address(0).
    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));
        vm.prank(owner);
        receipt.mintReceipt(address(0), URI);
    }

    /// El recibo es un ERC-721 normal: quien lo tiene puede transferirlo.
    function test_HolderCanTransferReceipt() public {
        vm.prank(owner);
        receipt.mintReceipt(alice, URI);

        vm.prank(alice);
        receipt.transferFrom(alice, bob, 0);
        assertEq(receipt.ownerOf(0), bob);
    }

    /// Declara soporte de ERC-165, ERC-721, ERC-721 Metadata y ERC-4906 (agregado por ERC721URIStorage).
    function test_SupportsInterfaces() public view {
        assertTrue(receipt.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(receipt.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(receipt.supportsInterface(0x5b5e139f)); // ERC-721 Metadata
        assertTrue(receipt.supportsInterface(0x49064906)); // ERC-4906 (MetadataUpdate)
        assertFalse(receipt.supportsInterface(0xffffffff));
    }
}
