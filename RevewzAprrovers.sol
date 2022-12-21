// SPDX-License-Identifier: All-rights reserved
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./struct/ApproverRewardAccount.sol";
import "./RevewzToken.sol";

/// @custom:security-contact projectrevewz@gmail.com
contract RevewzApproverSystem is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant APPROVER_ADMIN = keccak256("APPROVER_ADMIN");
    uint256 private maxRewardAmount;
    address private rvzTokenAddress;
    /// map the review cid or Harsh with the approver wallet that approved it
    mapping(string => ApproverRewardAccount) private approversRewards;
    mapping(address =>  uint256 ) private totalPayout;

/// sent reward event
    event RewardedApprover(
            address reviewerAddress,
            string reviewCID,
            uint256 rewardAmout,
            string status
        );

// added approver reward details on chain
event addApproverDataReward(
        address reviewerAddress,
        uint256 rewardAmout,
        string status
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address tokenAddress) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(APPROVER_ADMIN, msg.sender);
        _grantRole(APPROVER_ROLE, msg.sender);
        maxRewardAmount = 200;
        rvzTokenAddress = tokenAddress;
    }


  function getApproversdReward(string memory reviewHarsh)
        public
        view
        returns (ApproverRewardAccount memory)
    {
        require(
            approversRewards[reviewHarsh].exists == true,
            "Approver  does not exist on chain"
        );

        return approversRewards[reviewHarsh];
    }


 function getApproversTotalPayout(address  approverAddress)
        public
        view
        returns (uint256 )
    {
        return totalPayout[approverAddress];
    }


 ///@dev this method is used to send rewards of rvz erc20 token to users who sumbit reviews that have been approve
    function payoutApproverReward(string memory _reviewCID)
        public
        //internal changing to public , so it could be called externally
        onlyRole(APPROVER_ADMIN)
    {
        require(approversRewards[_reviewCID].exists == true, "review does not exist");
        
        require(
            approversRewards[_reviewCID].paid == false,
            "Reward already paid out approver"
        );
// just to ensure we are not sending over 200RVZ as reward to approvers
        require(approversRewards[_reviewCID].rewardBalance/1000000000000000000 < maxRewardAmount);
        
        RevewzToken token = RevewzToken(rvzTokenAddress);
        uint256 balance =  token.balanceOf(address(this));
        uint256 rewardAmt = approversRewards[_reviewCID].rewardBalance /1000000000000000000;
        require(balance > rewardAmt, "system does not have rvz to payout reward" );
        address receipient = approversRewards[_reviewCID].approver;
        approversRewards[_reviewCID].paid = true;
        token.transfer(receipient, rewardAmt);
        emit RewardedApprover(
            receipient,
            _reviewCID,
           rewardAmt,
            "successfull payed out  review reward entry on blockchain"
        );
    }

    

     ///@dev this method is used to add approvers wallet address and review CID to blockchain, this is needed to keep tract of all approvers who approved a review  on our platform. rewards are payedout based on this list
    //TODO update to add a role
    function addApproverReward(address _reviewer, string memory reviewHarsh,uint256 rewardAmount)
        public  onlyRole(APPROVER_ADMIN)
    {
        
        require(
            approversRewards[reviewHarsh].exists == false,
            "reward has already been submited for CID"
        );

        approversRewards[reviewHarsh] = ApproverRewardAccount(
            rewardAmount,
            false,
            false,
            _reviewer
        );
        /// create reward entry object and save in map, mapping it to the reviewHash or CID from ipfs

        emit addApproverDataReward(
            _reviewer,
            rewardAmount,
            "successfull saved approver reward entry on blockchain"
        );
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}



      function transferAdminRole(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, to);
        _grantRole(UPGRADER_ROLE, to);
        _grantRole(APPROVER_ADMIN, to);
        _grantRole(APPROVER_ROLE, to);
        _revokeRole(UPGRADER_ROLE, msg.sender);
        _revokeRole(APPROVER_ADMIN, msg.sender);
        _revokeRole(APPROVER_ROLE, msg.sender);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
