// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;
    address public alice = makeAddr("alice");

    function setUp() public {
        counter = new Counter();
    }

    function test_Owner() public view {
        assertEq(counter.owner(), address(this));
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function test_SetNumber_RevertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Counter.NotOwner.selector, alice));
        counter.setNumber(5);
    }

    function test_Increment_RevertsAtMax() public {
        counter.setNumber(100);
        vm.expectRevert(abi.encodeWithSelector(Counter.MaxReached.selector, 100));
        counter.increment();
    }

    function test_Increment_AllowsUpToMax() public {
        counter.setNumber(99);
        counter.increment();
        assertEq(counter.number(), counter.MAX());
    }

    function test_Emits_NumberSet() public {
        vm.expectEmit(true, false, false, true);
        emit Counter.NumberSet(address(this), 0, 7);
        counter.setNumber(7);
    }

    function test_Increment_Emits_NumberSet() public {
        counter.setNumber(41);
        vm.prank(alice); // increment no está restringido al owner
        vm.expectEmit(true, false, false, true);
        emit Counter.NumberSet(alice, 41, 42);
        counter.increment();
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
