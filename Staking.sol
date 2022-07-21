// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error TransferFailed();
error NeedsMoreThanZero();

contract Staking is ReentrancyGuard {
    IERC20 public _rewardsToken;
    IERC20 public _stakingToken;

    uint256 public constant REWARD_RATE = 100;
    uint256 public _lastUpdateTime;
    uint256 public _rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public _rewards;

    uint256 private s_totalSupply;
    mapping(address => uint256) public _balances;

    event Staked(address indexed user, uint256 indexed amount);
    event WithdrewStake(address indexed user, uint256 indexed amount);
    event RewardsClaimed(address indexed user, uint256 indexed amount);

    constructor(address stakingToken, address rewardsToken) {
        _stakingToken = IERC20(stakingToken);
        _rewardsToken = IERC20(rewardsToken);
    }

    function rewardPerToken() public view returns (uint256) {
        if (s_totalSupply == 0) {
            return _rewardPerTokenStored;
        }
        return
            _rewardPerTokenStored +
            (((block.timestamp - _lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return
            ((_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) /
                1e18) + _rewards[account];
    }

   
    function stake(uint256 amount)
        external
        updateReward(msg.sender)
        nonReentrant
        moreThanZero(amount)
    {
        s_totalSupply += amount;
        _balances[msg.sender] += amount;
        emit Staked(msg.sender, amount);
        bool success = _stakingToken.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    
    function withdraw(uint256 amount) external updateReward(msg.sender) nonReentrant {
        s_totalSupply -= amount;
        _balances[msg.sender] -= amount;
        emit WithdrewStake(msg.sender, amount);
        bool success = _stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    
    function claimReward() external updateReward(msg.sender) nonReentrant {
        uint256 reward = _rewards[msg.sender];
        _rewards[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, reward);
        bool success = _rewardsToken.transfer(msg.sender, reward);
        if (!success) {
            revert TransferFailed();
        }
    }


    modifier updateReward(address account) {
        _rewardPerTokenStored = rewardPerToken();
        _lastUpdateTime = block.timestamp;
        _rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }

    function getStaked(address account) public view returns (uint256) {
        return _balances[account];
    }
}
