// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking  {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public rewardRate = 100; // Reward rate in basis points (1/100th of a percent)
    uint256 public totalStaked;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userStaked;
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            userRewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) /
            totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return
            (userStaked[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            userRewards[account];
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        userStaked[msg.sender] += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(userStaked[msg.sender] >= amount, "Withdraw amount exceeds balance");
        totalStaked -= amount;
        userStaked[msg.sender] -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = userRewards[msg.sender];
        require(reward > 0, "No rewards available");
        userRewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function exit() external {
        withdraw(userStaked[msg.sender]);
        getReward();
    }

    function setRewardRate(uint256 _rewardRate) external  {
        rewardRate = _rewardRate;
    }
}
