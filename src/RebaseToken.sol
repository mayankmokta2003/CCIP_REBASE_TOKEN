// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20 ,Ownable,AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    bytes32 private constant BURN_AND_MINT_ROLE = keccak256("BURN_AND_MINT_ROLE");
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}


    function grantMintAndBurnRole(address account) external onlyOwner{
        _grantRole(BURN_AND_MINT_ROLE,account);
    }

    function setInterestRate(uint256 newInterestRate) external onlyOwner{
        if (s_interestRate > newInterestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, newInterestRate);
        }
        s_interestRate = newInterestRate;
        emit InterestRateSet(newInterestRate);
    }

    function mint(address _to, uint256 _amount) external onlyRole(BURN_AND_MINT_ROLE){
        // here first we will check if the user has not already minted before and now again minting so
        // if users again minting we want to apply the new interest rate not the previous one
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        super._mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(BURN_AND_MINT_ROLE){
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }

        _mintAccruedInterest(_from);
        _mint(_from, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of user(includes tokens already minted we can say)
        // multiply the principle balance by interest that has been made after the last timestamp
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest rate accumulated since last timestamp
        // this is linear  growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // pb(1 + (user interest rate * time elapsed))
        // eg deposited 10 tokens        interestrate 0.5 tokens per second       time elapsed 2secs
        // 10 + (10 * 0.5 * 2)

        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find the current balance of rabasetokens minted to the user before -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) and calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens needed to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint to mint the tokens to user
        _mint(_user, balanceIncrease);
    }

    function getuserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);

        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        // here we are saying that msg.sender is user and recipient is another user so if alice has 100 tokens
        // with 5% interest rate and she sends 20 tokens to bob so we want that bob hould also get same
        // interest rate of 5% as of alice.
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns(bool){
        _mintAccruedInterest(sender);
        _mintAccruedInterest(recipient);

        if(amount == type(uint256).max){
            amount = balanceOf(sender);
        }

        if(balanceOf(recipient) == 0){
            s_userInterestRate[recipient] = s_userInterestRate[sender];
        }
        return super.transferFrom(sender,recipient,amount);

    }
    // pb is the balance without any interest rate added suppose you gave 100 tokens in inetrest rate of 5%
    // so your principle balance is 100.
    function getPrincipleBalance(address user) external view returns(uint256){
        return super.balanceOf(user);
    }
    function getContractInterestrate() external view returns (uint256){
        return s_interestRate;
    }


}
