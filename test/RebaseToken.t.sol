// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() external {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        // (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // check our rebase token balance
        uint256 startingBalance = rebaseToken.balanceOf(user);
        assertEq(amount, startingBalance);
        console.log("startingbalanceeeee : ", startingBalance);
        // warp the time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalanceeeeee : ", middleBalance);
        assertGt(middleBalance, startingBalance);
        // warp the time again and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endingBalance = rebaseToken.balanceOf(user);
        console.log("endingBalanceeeeeee : ", endingBalance);
        // assertGt(endingBalance , middleBalance);
        // assertEq(middleBalance - startingBalance , endingBalance - middleBalance);
        // here the difference is just 1 wei so we did thiss
        assertApproxEqAbs(endingBalance - middleBalance, middleBalance - startingBalance, 1);
        vm.stopPrank();
    }

    // function testRedeemStraightAway(uint256 amount) public {
    //     // lets deposit first
    //     amount = bound(amount,1e5,type(uint96).max);
    //     vm.startPrank(user);
    //     vm.deal(user,amount);
    //     vault.deposit{value: amount}();

    //     vault.redeem(type(uint256).max);
    //     assertEq(rebaseToken.balanceOf(user),0);
    //     assertEq(address(user).balance,amount);
    //     vm.stopPrank();
    // }

    function testRedeemAfterTimeHasPassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max); // this is a crazy number of years - 2^96 seconds is a lot
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // this is an Ether value of max 2^78 which is crazy

        // Deposit funds
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // check the balance has increased after some time has passed
        vm.warp(time);

        // Get balance after time has passed
        uint256 balance = rebaseToken.balanceOf(user);

        // Add rewards to the vault
        vm.deal(owner, balance - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balance - depositAmount);

        // Redeem funds
        vm.prank(user);
        vault.redeem(balance);

        uint256 ethBalance = address(user).balance;

        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 balanceUser1 = rebaseToken.balanceOf(user);
        uint256 balanceUser2 = rebaseToken.balanceOf(user2);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 afterBalanceUser1 = rebaseToken.balanceOf(user);
        uint256 afterBalanceUser2 = rebaseToken.balanceOf(user2);

        // assertEq(afterBalanceUser1 , afterBalanceUser1 - amount);
        assertEq(afterBalanceUser1, balanceUser1 - amountToSend);
        assertEq(afterBalanceUser2, amountToSend);
        assertEq(rebaseToken.getuserInterestRate(user2), rebaseToken.getuserInterestRate(user));
    }

    function testOnlyOwnerCanSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testNewInterestRateIsGreaterThanTheOldOne(uint256 newInterestRatee) public {
        uint256 initialInterestrate = rebaseToken.getContractInterestrate();
        newInterestRatee = bound(newInterestRatee, initialInterestrate + 1, type(uint96).max);
        vm.prank(owner);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRatee);
    }

    // function testOwnerCannotCallMintAndBurn(uint256 amount) public {
    //     vm.prank(owner);
    //     vm.expectRevert();
    //     rebaseToken.mint(address(owner), amount, rebaseToken.getInterestRate());
    //     vm.expectRevert();
    //     rebaseToken.burn(owner, amount);
    // }

    // function testCannotCallAndMint() public {
    //     vm.prank(user);
    //     vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
    //     rebaseToken.mint(user, 100, rebaseToken.getInterestRate());
    //     vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
    //     rebaseToken.burn(user, 100);
    // }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 Pa = rebaseToken.getPrincipleBalance(user);
        assertEq(Pa, amount);
    }

    function testGetContractInterestRate() public {
        uint256 actualInterestrate = rebaseToken.getContractInterestrate();
    }

    function testgetRebaseTokenAddressOfContract() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }
}
