// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MetaDeltaProtocol
 * @dev Configurable fee routing and delta-based distribution protocol
 * @notice Allows registering strategies and routing incoming ETH across them by weight
 */
contract MetaDeltaProtocol {
    address public owner;

    struct Strategy {
        uint256 id;
        string  name;
        uint256 weight;      // relative weight for fee splitting (in arbitrary units)
        bool    isActive;
    }

    // strategyId => Strategy
    mapping(uint256 => Strategy) public strategies;

    // Active strategies list
    uint256[] public activeStrategyIds;

    // Accrued balances per strategy (pull pattern)
    mapping(uint256 => uint256) public accruedForStrategy;

    // Global counters
    uint256 public nextStrategyId;
    uint256 public totalWeight;
    uint256 public totalRouted;

    event StrategyRegistered(
        uint256 indexed id,
        string name,
        uint256 weight
    );

    event StrategyUpdated(
        uint256 indexed id,
        uint256 oldWeight,
        uint256 newWeight,
        bool isActive
    );

    event FeesRouted(
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );

    event StrategyWithdrawn(
        uint256 indexed id,
        address indexed to,
        uint256 amount
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier strategyExists(uint256 id) {
        require(bytes(strategies[id].name).length != 0, "Strategy not found");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Register a new strategy
     * @param name Human-readable name
     * @param weight Relative weight for fee routing
     */
    function registerStrategy(string calldata name, uint256 weight)
        external
        onlyOwner
        returns (uint256 id)
    {
        require(weight > 0, "Weight = 0");

        id = nextStrategyId++;
        strategies[id] = Strategy({
            id: id,
            name: name,
            weight: weight,
            isActive: true
        });

        activeStrategyIds.push(id);
        totalWeight += weight;

        emit StrategyRegistered(id, name, weight);
    }

    /**
     * @dev Update strategy weight and active flag
     */
    function updateStrategy(uint256 id, uint256 newWeight, bool isActive)
        external
        onlyOwner
        strategyExists(id)
    {
        Strategy storage s = strategies[id];
        uint256 oldWeight = s.weight;

        // adjust totalWeight
        if (oldWeight != newWeight) {
            if (newWeight == 0) {
                totalWeight -= oldWeight;
            } else {
                totalWeight = totalWeight - oldWeight + newWeight;
            }
            s.weight = newWeight;
        }

        s.isActive = isActive;

        emit StrategyUpdated(id, oldWeight, newWeight, isActive);
    }

    /**
     * @dev Receive ETH and route across strategies according to weights
     */
    receive() external payable {
        _route(msg.value);
    }

    /**
     * @dev Explicit function to route ETH sent with the call
     */
    function route() external payable {
        require(msg.value > 0, "Amount = 0");
        _route(msg.value);
    }

    function _route(uint256 amount) internal {
        require(totalWeight > 0, "No active weight");

        uint256 remaining = amount;

        // simple proportional distribution using integer math
        uint256 len = activeStrategyIds.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 id = activeStrategyIds[i];
            Strategy memory s = strategies[id];
            if (!s.isActive || s.weight == 0) continue;

            uint256 share = (amount * s.weight) / totalWeight;
            if (i == len - 1) {
                // send remainder to last strategy to ensure full allocation
                share = remaining;
            }

            if (share > 0) {
                accruedForStrategy[id] += share;
                remaining -= share;
            }
        }

        totalRouted += amount;
        emit FeesRouted(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Withdraw funds accrued for a given strategy to a target address
     * @param id Strategy id
     * @param to Recipient address
     */
    function withdrawStrategy(uint256 id, address to)
        external
        onlyOwner
        strategyExists(id)
    {
        require(to != address(0), "Zero address");

        uint256 amount = accruedForStrategy[id];
        require(amount > 0, "Nothing to withdraw");

        accruedForStrategy[id] = 0;

        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "Transfer failed");

        emit StrategyWithdrawn(id, to, amount);
    }

    /**
     * @dev Get all active strategy IDs
     */
    function getActiveStrategyIds() external view returns (uint256[] memory) {
        return activeStrategyIds;
    }

    /**
     * @dev Get contract ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
