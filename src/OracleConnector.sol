// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/**
 * @title OracleConnector
 * @notice Interface para atualizar métricas de campanhas com dados externos
 * @dev Acesso restrito ao backend/oráculo autorizado
 */
contract OracleConnector is Ownable {
    // Eventos
    event MetricsUpdated(uint256 campaignId, uint256 likes, uint256 views);
    
    // Endereço do contrato CampaignManager
    address public campaignManager;
    
    // Mapeamento de oráculos autorizados
    mapping(address => bool) public authorizedOracles;
    
    // Modificador para restringir acesso apenas a oráculos autorizados
    modifier onlyOracle() {
        require(authorizedOracles[msg.sender], "OracleConnector: caller is not an authorized oracle");
        _;
    }
    
    constructor() {
        _initializeOwner(msg.sender);
    }
    
    /**
     * @notice Define o endereço do contrato CampaignManager
     * @param _campaignManager Endereço do contrato CampaignManager
     */
    function setCampaignManager(address _campaignManager) external onlyOwner {
        require(_campaignManager != address(0), "OracleConnector: invalid campaign manager address");
        campaignManager = _campaignManager;
    }
    
    /**
     * @notice Adiciona um oráculo autorizado
     * @param oracle Endereço do oráculo a ser autorizado
     */
    function addOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "OracleConnector: invalid oracle address");
        authorizedOracles[oracle] = true;
    }
    
    /**
     * @notice Remove um oráculo autorizado
     * @param oracle Endereço do oráculo a ser removido
     */
    function removeOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = false;
    }
    
    /**
     * @notice Atualiza as métricas de uma campanha
     * @param campaignId ID da campanha
     * @param likes Número de likes
     * @param views Número de views
     */
    function updateCampaignMetrics(uint256 campaignId, uint256 likes, uint256 views) external onlyOracle {
        require(campaignManager != address(0), "OracleConnector: campaign manager not set");
        
        // Chama a função de atualização de métricas no CampaignManager
        (bool success, bytes memory data) = campaignManager.call(
            abi.encodeWithSignature("updateMetrics(uint256,uint256,uint256)", campaignId, likes, views)
        );
        
        require(success, "OracleConnector: failed to update metrics");
        
        emit MetricsUpdated(campaignId, likes, views);
    }
}