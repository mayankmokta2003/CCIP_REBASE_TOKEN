// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";

contract RebaseTokenTest is Test{

    RebaseToken private rebaseToken;
    Vault private vault;
    address owner = makeAddr("owner");
    address user = makeAddr("user");


    function setUp() external {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }


    function testDepositLinear(uint256 amount) public {
        vm.assume(amount > 1e5);
        amount = bound(amount,1e5,type(uint96).max);
        // deposit
        vm.startPrank(user);
        vm.deal(user,amount);
        // check our rebase token balance
        // warp the time and check balance again
        // warp the time again and check the balance again
        vm.stopPrank();
    }



}