// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

/**
 * @title PaymentVault
 * @notice Gerencia os pagamentos das campanhas usando o padrão pull payment
 * @dev Trava os fundos até que as milestones sejam atingidas
 */
contract PaymentVault is Ownable {
    using SafeTransferLib for address;
    
    // Endereço do token USDC
    address public immutable usdcToken;
    
    // Endereço do CampaignManager
    address public campaignManager;
    
    // Mapeamento de pagamentos pendentes por criador
    mapping(address => uint256) public pendingPayments;
    
    // Eventos
    event FundsDeposited(uint256 campaignId, address brand, uint256 amount);
    event PaymentReleased(uint256 campaignId, address creator, uint256 amount);
    event PaymentWithdrawn(address creator, uint256 amount);
    
    // Modificador para restringir acesso apenas ao CampaignManager
    modifier onlyCampaignManager() {
        require(msg.sender == campaignManager, "PaymentVault: caller is not the campaign manager");
        _;
    }
    
    constructor(address _usdcToken) {
        require(_usdcToken != address(0), "PaymentVault: invalid USDC token address");
        usdcToken = _usdcToken;
        _initializeOwner(msg.sender);
    }
    
    /**
     * @notice Define o endereço do contrato CampaignManager
     * @param _campaignManager Endereço do contrato CampaignManager
     */
    function setCampaignManager(address _campaignManager) external onlyOwner {
        require(_campaignManager != address(0), "PaymentVault: invalid campaign manager address");
        campaignManager = _campaignManager;
    }
    
    /**
     * @notice Deposita fundos para uma campanha
     * @param campaignId ID da campanha
     * @param brand Endereço da marca
     * @param amount Valor a ser depositado
     */
    function depositFunds(uint256 campaignId, address brand, uint256 amount) external onlyCampaignManager {
        require(amount > 0, "PaymentVault: amount must be greater than zero");
        
        // Transfere os tokens USDC da marca para este contrato
        SafeTransferLib.safeTransferFrom(usdcToken, brand, address(this), amount);
        
        emit FundsDeposited(campaignId, brand, amount);
    }
    
    /**
     * @notice Libera pagamento para um criador quando uma milestone é atingida
     * @param campaignId ID da campanha
     * @param creator Endereço do criador
     * @param amount Valor a ser liberado
     */
    function releasePayment(uint256 campaignId, address creator, uint256 amount) external onlyCampaignManager {
        require(creator != address(0), "PaymentVault: invalid creator address");
        require(amount > 0, "PaymentVault: amount must be greater than zero");
        
        // Adiciona o pagamento ao saldo pendente do criador
        pendingPayments[creator] += amount;
        
        emit PaymentReleased(campaignId, creator, amount);
    }
    
    /**
     * @notice Permite que um criador saque seus pagamentos pendentes
     */
    function withdrawPayment() external {
        address creator = msg.sender;
        uint256 amount = pendingPayments[creator];
        
        require(amount > 0, "PaymentVault: no pending payments");
        
        // Zera o saldo pendente antes da transferência para evitar reentrância
        pendingPayments[creator] = 0;
        
        // Transfere os tokens USDC para o criador
        SafeTransferLib.safeTransfer(usdcToken, creator, amount);
        
        emit PaymentWithdrawn(creator, amount);
    }
    
    /**
     * @notice Retorna o saldo pendente de um criador
     * @param creator Endereço do criador
     * @return Saldo pendente
     */
    function getPendingPayment(address creator) external view returns (uint256) {
        return pendingPayments[creator];
    }
}