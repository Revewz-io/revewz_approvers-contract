// SPDX-License-Identifier: Revewz Organization
pragma solidity ^0.8.4;

import "./struct/RewardAccount.sol";
import "./RevewzToken.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";


contract RevewzRewardSystem is
    Initializable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant ADMIN_APPROVER_ROLE =
        keccak256("ADMIN_APPROVER_ROLE");
    mapping(string => RewardAccount) private userReward;
    mapping(address => bool) private approvers;
    ///@dev  this  is use to keep track of the current reward rate at the time of awarding the reward
    uint256 private rewardRate;
    uint256 private epochStartdate;
    uint256 private epochReward;
    address private rvzTokenAddress;

    event SubmitedReviewReward(
        address reviewerAddress,
        uint256 rewardAmout,
        string status
    );

    event ApproveReview(
        address approverAddress,
        string reviewCID,
        string status
    );

    event RejectReview(
        address approverAddress,
        string reviewCID,
        string status
    );

    event RewardedReviewer(
        address reviewerAddress,
        string reviewCID,
        uint256 rewardAmout,
        string status
    );

    event MintedRewardTokens(
        address addressToRecieveTokens,
        uint256 tokensMinted,
        string status
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address tokenAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(REWARDER_ROLE, msg.sender);
        _grantRole(APPROVER_ROLE, msg.sender);
        _grantRole(ADMIN_APPROVER_ROLE, msg.sender);
        _setRoleAdmin(APPROVER_ROLE, ADMIN_APPROVER_ROLE);
        rewardRate = 693_147_180_559_945;
        epochReward = 100;
        epochStartdate = block.timestamp;
        approvers[msg.sender] = true;
        rvzTokenAddress = tokenAddress;
    }

    ///@dev to use this contract to mint rvz coins to reward users. after deplying RVZ token smart contract and this smart contract (RevewzRewardSystem) call this
    ///@dev assign a minter role to this smart contract and call this method to mint RVZ tokens to the RevewzRewardSystem contract
    ///@dev after the mint revoke the minter role from this smart contract
    function mintRewardTokens(
        address revewRewardSytemAddress,
        uint256 tokenAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        RevewzToken token = RevewzToken(rvzTokenAddress);
        token.mint(revewRewardSytemAddress, tokenAmount);
        emit MintedRewardTokens(
            revewRewardSytemAddress,
            tokenAmount,
            "succesfully minted tokens to contract address provided "
        );
    }

    ///@dev this method is used to send rewards of rvz erc20 token to users who sumbit reviews that have been approve
    function sendReward(string memory _reviewCID)
        public
        //internal changing to public , so it could be called externally
        onlyRole(REWARDER_ROLE)
    {
        require(userReward[_reviewCID].exists == true, "review does not exist");
        require(
            userReward[_reviewCID].verified == true,
            "Review not verified "
        );
        require(
            userReward[_reviewCID].approved == true,
            "Review not  approved"
        );
        require(
            userReward[_reviewCID].paid == false,
            "Reward already paid out"
        );
        RevewzToken token = RevewzToken(rvzTokenAddress);
        uint256 balance =  token.balanceOf(address(this));
        uint256 rewardAmt = userReward[_reviewCID].rewardBalance /1000000000000000000;
        require(balance > rewardAmt, "system does not have rvz to payout reward" );
        address receipient = userReward[_reviewCID].submitedBy;
        userReward[_reviewCID].paid = true;
        token.transfer(receipient, rewardAmt);
        emit RewardedReviewer(
            receipient,
            _reviewCID,
           rewardAmt,
            "successfull payed out  review reward entry on blockchain"
        );
    }

    function validateReview(
        address _approver,
        string memory reviewHarsh,
        bool approved
    ) public onlyRole(APPROVER_ROLE) {
        /// ensure approver has the right to approve
        require(approvers[_approver] == true, "not an approver");
        require(
            userReward[reviewHarsh].exists == true,
            "no valid review exist"
        );
        //since we are using the approved flag for both reject and approved reviews, we need another flag as to let us know what revies
        //have been processed, hence the verified flag. so a verified flag of true and approved of false means , review was rejected
        require(
            userReward[reviewHarsh].verified == false,
            "review has already been verified"
        );
        // ensure we are not paying  or rewarding a review  more than once

        require(
            userReward[reviewHarsh].paid == false,
            "reward has already been paid out"
        );

        //ensure we are approving the right review
        require(
            keccak256(abi.encodePacked(userReward[reviewHarsh].reviewCID)) ==
                keccak256(abi.encodePacked(reviewHarsh)),
            "tried to approve wrong review"
        );
        //udpate verified to be true
        if (approved == true) {
            userReward[reviewHarsh].verified = true;
            userReward[reviewHarsh].approved = true;
            emit ApproveReview(
                _approver,
                reviewHarsh,
                "approved review successfully"
            );
        } else {
            userReward[reviewHarsh].verified = true;
            userReward[reviewHarsh].approved = false;
            emit RejectReview(_approver, reviewHarsh, "Rejected review ");
        }
    }

    ///@dev this method is used to add reviewers wallet address and review CID to blockchain, this is needed to keep tract of all reviews submited to our platform. rewards are payedout based on this list
    //TODO update to add a role
    function submitReviewReward(address _reviewer, string memory reviewHarsh)
        public
    {
        //calculate the time elasped since deploying smart contract in months
        require(
            userReward[reviewHarsh].exists == false,
            "review has already been submited"
        );
        require(
            block.timestamp > epochStartdate,
            "epoch start-time <  than now"
        );
        uint256 dateElasped = ((block.timestamp - epochStartdate) / 30 days) +
            1;

        /// @dev calcualte the reward amount  (rewardRate /10000000000000000 )*  dateElasped  * epochReward;
        uint256 rewardAmount = ((rewardRate * epochReward * 10**decimals()) /
            (1000_000_000_000_000 * dateElasped));
        userReward[reviewHarsh] = RewardAccount(
            rewardAmount,
            false,
            false,
            false,
            reviewHarsh,
            _reviewer,
            true
        );
        /// create reward entry object and save in map, mapping it to the reviewHash or CID from ipfs

        emit SubmitedReviewReward(
            _reviewer,
            rewardAmount,
            "successfull saved review entry on blockchain"
        );
    }

    function getRewardReview(string memory reviewHarsh)
        public
        view
        returns (RewardAccount memory)
    {
        require(
            userReward[reviewHarsh].exists == true,
            "review  does not exist on chain"
        );

        return userReward[reviewHarsh];
    }

    function addApprover(address approver)
        public
        onlyRole(ADMIN_APPROVER_ROLE)
    {
        _grantRole(APPROVER_ROLE, approver);
        approvers[approver] = true;
    }

    function addRewarder(address rewarder) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(REWARDER_ROLE, rewarder);
    }

   

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function transferAdminRole(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, to);
        _grantRole(UPGRADER_ROLE, to);
        _grantRole(REWARDER_ROLE, to);
        _grantRole(ADMIN_APPROVER_ROLE, to);
        _grantRole(APPROVER_ROLE, to);
        _revokeRole(UPGRADER_ROLE, msg.sender);
        _revokeRole(APPROVER_ROLE, msg.sender);
        _revokeRole(REWARDER_ROLE, msg.sender);
        _revokeRole(ADMIN_APPROVER_ROLE, msg.sender);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
