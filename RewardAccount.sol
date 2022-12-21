// SPDX-License-Identifier: Revewz Organization
pragma solidity ^0.8.4;

struct RewardAccount {
    uint256 rewardBalance;
    bool paid;
    bool verified;
    bool approved;
    string reviewCID;
    address submitedBy;
    bool exists;
}
