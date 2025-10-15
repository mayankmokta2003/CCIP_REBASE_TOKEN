// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from
    "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "../lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {Script} from "forge-std/Script.sol";

contract BridgeTokensScript is Script {
    function run(
        uint64 destinationChainSelector,
        address routerAddress,
        address receiverAddress,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        uint256 ccipFee
    ) public {
        vm.startBroadcast();
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSendAddress, amount: amountToSend});
        // Client.EVMExtraArgsV1[] memory extra = new Client.EVMExtraArgsV1[](1);
        // extra[0] = Client.EVMExtraArgsV1({
        //     gasLimit: 0
        // }); we didnot do this because it expects in bytes not in array
        // creating message
        Client.EVM2AnyMessage[] memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            // for data EVMTokenAmount struct has data in it;
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        vm.stopBroadcast();
    }
}
