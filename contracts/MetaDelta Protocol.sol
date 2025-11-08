Struct to store metadata information
    struct MetaData {
        string content;
        uint256 version;
        uint256 timestamp;
        address lastModifier;
        bool isActive;
    }
    
    Mapping from metadata ID to MetaData
    mapping(uint256 => MetaData) public metadata;
    
    Counter for metadata IDs
    uint256 public metadataCounter;
    
    Events
    event MetadataCreated(uint256 indexed metadataId, address indexed creator, string content, uint256 timestamp);
    event MetadataUpdated(uint256 indexed metadataId, address indexed updater, uint256 version, uint256 timestamp);
    event MetadataDeactivated(uint256 indexed metadataId, address indexed deactivator, uint256 timestamp);
    
    /**
     * @dev Creates new metadata entry
     * @param _content The initial content of the metadata
     * @return metadataId The ID of the newly created metadata
     */
    function createMetadata(string memory _content) public returns (uint256) {
        require(bytes(_content).length > 0, "Content cannot be empty");
        
        metadataCounter++;
        uint256 newMetadataId = metadataCounter;
        
        metadata[newMetadataId] = MetaData({
            content: _content,
            version: 1,
            timestamp: block.timestamp,
            lastModifier: msg.sender,
            isActive: true
        });
        
        userMetadata[msg.sender].push(newMetadataId);
        
        emit MetadataCreated(newMetadataId, msg.sender, _content, block.timestamp);
        
        return newMetadataId;
    }
    
    /**
     * @dev Updates existing metadata and tracks delta changes
     * @param _metadataId The ID of the metadata to update
     * @param _newContent The new content for the metadata
     */
    function updateMetadata(uint256 _metadataId, string memory _newContent) public {
        require(_metadataId > 0 && _metadataId <= metadataCounter, "Invalid metadata ID");
        require(metadata[_metadataId].isActive, "Metadata is not active");
        require(bytes(_newContent).length > 0, "New content cannot be empty");
        
        MetaData storage meta = metadata[_metadataId];
        
        Update metadata
        meta.content = _newContent;
        meta.version++;
        meta.timestamp = block.timestamp;
        meta.lastModifier = msg.sender;
        
        emit MetadataUpdated(_metadataId, msg.sender, meta.version, block.timestamp);
    }
    
    /**
     * @dev Retrieves complete delta history for a metadata entry
     * @param _metadataId The ID of the metadata
     * @return Array of all delta changes for the specified metadata
     */
    function getDeltaHistory(uint256 _metadataId) public view returns (DeltaChange[] memory) {
        require(_metadataId > 0 && _metadataId <= metadataCounter, "Invalid metadata ID");
        return deltaHistory[_metadataId];
    }
    
    /**
     * @dev Deactivates metadata entry
     * @param _metadataId The ID of the metadata to deactivate
     */
    function deactivateMetadata(uint256 _metadataId) public {
        require(_metadataId > 0 && _metadataId <= metadataCounter, "Invalid metadata ID");
        require(metadata[_metadataId].isActive, "Metadata is already inactive");
        
        metadata[_metadataId].isActive = false;
        
        emit MetadataDeactivated(_metadataId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Retrieves all metadata IDs for a specific user
     * @param _user The address of the user
     * @return Array of metadata IDs created by the user
     */
    function getUserMetadata(address _user) public view returns (uint256[] memory) {
        return userMetadata[_user];
    }
    
    /**
     * @dev Retrieves metadata details
     * @param _metadataId The ID of the metadata
     * @return content The current content
     * @return version The current version number
     * @return timestamp The last update timestamp
     * @return lastModifier The address of the last modifier
     * @return isActive Whether the metadata is active
     */
    function getMetadata(uint256 _metadataId) public view returns (
        string memory content,
        uint256 version,
        uint256 timestamp,
        address lastModifier,
        bool isActive
    ) {
        require(_metadataId > 0 && _metadataId <= metadataCounter, "Invalid metadata ID");
        MetaData memory meta = metadata[_metadataId];
        return (meta.content, meta.version, meta.timestamp, meta.lastModifier, meta.isActive);
    }
}
// 
End
// 
