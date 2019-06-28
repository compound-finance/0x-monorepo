/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity ^0.5.5;

import "../libs/LibSafeMath.sol";
import "../libs/LibRewardMath.sol";
import "../immutable/MixinStorage.sol";
import "../immutable/MixinConstants.sol";
import "./MixinStakeBalances.sol";
import "./MixinStakingPoolRewardVault.sol";
import "./MixinStakingPool.sol";


contract MixinStakingPoolRewards is
    MixinConstants,
    MixinStorage,
    MixinStakingPoolRewardVault,
    MixinStakeBalances,
    MixinStakingPool
{

    using LibSafeMath for uint256;

    /// @dev This mixin contains logic for staking pool rewards.
    /// Rewards for a pool are generated by their market makers trading on the 0x protocol (MixinStakingPool).
    /// The operator of a pool receives a fixed percentage of all rewards; generally, the operator is the
    /// sole market maker of a pool. The remaining rewards are divided among the members of a pool; each member
    /// gets an amount proportional to how much stake they have delegated to the pool.
    ///
    /// Note that members can freely join or leave a staking pool at any time, by delegating/undelegating their stake.
    /// Moreover, there is no limit to how many members a pool can have. To limit the state-updates needed to track member balances,
    /// we store only a single balance shared by all members. This state is updated every time a reward is paid to the pool - which
    /// is currently at the end of each epoch. Additionally, each member has an associated "Shadow Balance" which is updated only
    /// when a member delegates/undelegates stake to the pool, along with a "Total Shadow Balance" that represents the cumulative
    /// Shadow Balances of all members in a pool.
    /// 
    /// -- Member Balances --
    /// Terminology:
    ///     Real Balance - The reward balance in ETH of a member.
    ///     Total Real Balance - The sum total of reward balances in ETH across all members of a pool.
    ///     Shadow Balance - The realized reward balance of a member.
    ///     Total Shadow Balance - The sum total of realized reward balances across all members of a pool.
    /// How it works:
    /// 1. When a member delegates, their ownership of the pool increases; however, this new ownership applies
    ///    only to future rewards and must not change the rewards currently owned by other members. Thus, when a
    ///    member delegates stake, we *increase* their Shadow Balance and the Total Shadow Balance of the pool.
    ///
    /// 2. When a member withdraws a portion of their reward, their realized balance increases but their ownership
    ///    within the pool remains unchanged. Thus, we simultaneously *decrease* their Real Balance and 
    ///    *increase* their Shadow Balance by the amount withdrawn. The cumulative balance decrease and increase, respectively.
    ///
    /// 3. When a member undelegates, the portion of their reward that corresponds to that stake is also withdrawn. Thus,
    ///    their realized balance *increases* while their ownership of the pool *decreases*. To reflect this, we 
    ///    decrease their Shadow Balance, the Total Shadow Balance, their Real Balance, and the Total Real Balance.

    
    function getRewardBalance(bytes32 poolId)
        external
        view
        returns (uint256)
    {
        return getBalanceInStakingPoolRewardVault(poolId);
    }

    function getRewardBalanceOfOperator(bytes32 poolId)
        external
        view
        returns (uint256)
    {
        return getBalanceOfOperatorInStakingPoolRewardVault(poolId);
    }

    function getRewardBalanceOfPool(bytes32 poolId)
        external
        view
        returns (uint256)
    {
        return getBalanceOfPoolInStakingPoolRewardVault(poolId);
    }

    function computeRewardBalance(bytes32 poolId, address owner)
        public
        view
        returns (uint256)
    {
        uint256 poolBalance = getBalanceOfPoolInStakingPoolRewardVault(poolId);
        return LibRewardMath._computePayoutDenominatedInRealAsset(
            delegatedStakeToPoolByOwner[owner][poolId],
            delegatedStakeByPoolId[poolId],
            shadowRewardsInPoolByOwner[owner][poolId],
            shadowRewardsByPoolId[poolId],
            poolBalance
        );
    }

    function withdrawOperatorReward(bytes32 poolId, uint256 amount)
        external
        onlyStakingPoolOperator(poolId)
    {
        _withdrawFromOperatorInStakingPoolRewardVault(poolId, amount);
        poolById[poolId].operatorAddress.transfer(amount);
    }

    function withdrawReward(bytes32 poolId, uint256 amount)
        external
    {
        address payable owner = msg.sender;
        uint256 ownerBalance = computeRewardBalance(poolId, owner);
        require(
            amount <= ownerBalance,
            "INVALID_AMOUNT"
        );

        shadowRewardsInPoolByOwner[owner][poolId] = shadowRewardsInPoolByOwner[owner][poolId]._add(amount);
        shadowRewardsByPoolId[poolId] = shadowRewardsByPoolId[poolId]._add(amount);

        _withdrawFromPoolInStakingPoolRewardVault(poolId, amount);
        owner.transfer(amount);
    }

    function withdrawTotalOperatorReward(bytes32 poolId)
        external
        onlyStakingPoolOperator(poolId)
        returns (uint256)
    {
        uint256 amount = getBalanceOfOperatorInStakingPoolRewardVault(poolId);
        _withdrawFromOperatorInStakingPoolRewardVault(poolId, amount);
        poolById[poolId].operatorAddress.transfer(amount);

        return amount;
    }

    function withdrawTotalReward(bytes32 poolId)
        external
        returns (uint256)
    {
        address payable owner = msg.sender;
        uint256 amount = computeRewardBalance(poolId, owner);

        shadowRewardsInPoolByOwner[owner][poolId] = shadowRewardsInPoolByOwner[owner][poolId]._add(amount);
        shadowRewardsByPoolId[poolId] = shadowRewardsByPoolId[poolId]._add(amount);

        _withdrawFromPoolInStakingPoolRewardVault(poolId, amount);
        owner.transfer(amount);

        return amount;
    }


    

    function getShadowBalanceByPoolId(bytes32 poolId)
        public
        view
        returns (uint256)
    {
        return shadowRewardsByPoolId[poolId];
    }

    function getShadowBalanceInPoolByOwner(address owner, bytes32 poolId)
        public
        view
        returns (uint256)
    {
        return shadowRewardsInPoolByOwner[owner][poolId];
    }
}