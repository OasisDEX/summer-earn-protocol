/**
 * @title IConfigurationManager
 * @notice Interface for the ConfigurationManager contract, which manages system-wide parameters
 * @dev This interface defines the getters and setters for system-wide parameters
 */
interface IConfigurationManager is IConfigurationManagerEvents {
    /**
     * @notice Get the address of the Raft contract
     * @return The address of the Raft contract
     */
    function raft() external returns (address);

    /**
     * @notice Get the current tip rate
     * @return The current tip rate as a uint8
     */
    function tipRate() external returns (uint8);

    /**
     * @notice Set a new address for the Raft contract
     * @param newRaft The new address for the Raft contract
     * @dev Can only be called by the governor
     */
    function setRaft(address newRaft) external;

    /**
     * @notice Set a new tip rate
     * @param newTipRate The new tip rate to set
     * @dev Can only be called by the governor
     */
    function setTipRate(uint8 newTipRate) external;
}