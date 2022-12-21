// SPDX-License-Identifier: All-rights reserved
pragma solidity ^0.8.9;

struct ApproverRewardAccount {
    uint256 rewardBalance;
    bool paid;
    bool exists;
    address approver;
}
