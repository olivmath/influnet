// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {PaymentVault} from "./PaymentVault.sol";
import {OracleConnector} from "./OracleConnector.sol";

/**
 * @title CampaignManager
 * @notice Gerencia o ciclo de vida das campanhas de divulgação
 * @dev Associa criadores, marcas, KPIs, valores e prazos
 */
contract CampaignManager is Ownable {
    // Estrutura para armazenar informações da campanha
    struct Campaign {
        address brand;          // Endereço da marca
        address creator;        // Endereço do criador
        uint256 totalValue;     // Valor total da campanha em USDC
        uint256 deadline;       // Prazo final da campanha (timestamp)
        uint256 targetLikes;    // Meta de likes
        uint256 targetViews;    // Meta de views
        uint256 currentLikes;   // Likes atuais
        uint256 currentViews;   // Views atuais
        uint256 paidAmount;     // Valor já pago ao criador
        CampaignStatus status;  // Status atual da campanha
    }
    
    // Enum para status da campanha
    enum CampaignStatus {
        Created,    // Campanha criada, aguardando depósito
        Active,     // Campanha ativa, em andamento
        Completed,  // Campanha concluída com sucesso
        Cancelled,  // Campanha cancelada
        Expired     // Campanha expirada (prazo atingido sem completar)
    }
    
    // Contador de IDs de campanhas
    uint256 public campaignCounter;
    
    // Mapeamento de campanhas por ID
    mapping(uint256 => Campaign) public campaigns;
    
    // Endereço do contrato PaymentVault
    PaymentVault public paymentVault;
    
    // Endereço do contrato OracleConnector
    address public oracleConnector;
    
    // Eventos
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed brand,
        address indexed creator,
        uint256 totalValue,
        uint256 deadline,
        uint256 targetLikes,
        uint256 targetViews
    );
    event CampaignStarted(uint256 indexed campaignId);
    event CampaignCompleted(uint256 indexed campaignId);
    event CampaignCancelled(uint256 indexed campaignId);
    event CampaignExpired(uint256 indexed campaignId);
    event MetricsUpdated(uint256 indexed campaignId, uint256 likes, uint256 views);
    event MilestoneAchieved(uint256 indexed campaignId, uint256 amount);
    
    // Modificador para verificar se o chamador é o OracleConnector
    modifier onlyOracle() {
        require(msg.sender == oracleConnector, "CampaignManager: caller is not the oracle connector");
        _;
    }
    
    // Modificador para verificar se o chamador é a marca da campanha
    modifier onlyBrand(uint256 campaignId) {
        require(campaigns[campaignId].brand == msg.sender, "CampaignManager: caller is not the brand");
        _;
    }
    
    constructor(address _paymentVault) {
        require(_paymentVault != address(0), "CampaignManager: invalid payment vault address");
        paymentVault = PaymentVault(_paymentVault);
        _initializeOwner(msg.sender);
    }
    
    /**
     * @notice Define o endereço do contrato OracleConnector
     * @param _oracleConnector Endereço do contrato OracleConnector
     */
    function setOracleConnector(address _oracleConnector) external onlyOwner {
        require(_oracleConnector != address(0), "CampaignManager: invalid oracle connector address");
        oracleConnector = _oracleConnector;
    }
    
    /**
     * @notice Cria uma nova campanha
     * @param creator Endereço do criador
     * @param totalValue Valor total da campanha em USDC
     * @param durationDays Duração da campanha em dias
     * @param targetLikes Meta de likes
     * @param targetViews Meta de views
     * @return campaignId ID da campanha criada
     */
    function createCampaign(
        address creator,
        uint256 totalValue,
        uint256 durationDays,
        uint256 targetLikes,
        uint256 targetViews
    ) external returns (uint256 campaignId) {
        require(creator != address(0), "CampaignManager: invalid creator address");
        require(totalValue > 0, "CampaignManager: total value must be greater than zero");
        require(durationDays > 0, "CampaignManager: duration must be greater than zero");
        require(targetLikes > 0 || targetViews > 0, "CampaignManager: at least one target metric must be set");
        
        campaignId = campaignCounter++;
        uint256 deadline = block.timestamp + (durationDays * 1 days);
        
        campaigns[campaignId] = Campaign({
            brand: msg.sender,
            creator: creator,
            totalValue: totalValue,
            deadline: deadline,
            targetLikes: targetLikes,
            targetViews: targetViews,
            currentLikes: 0,
            currentViews: 0,
            paidAmount: 0,
            status: CampaignStatus.Created
        });
        
        emit CampaignCreated(
            campaignId,
            msg.sender,
            creator,
            totalValue,
            deadline,
            targetLikes,
            targetViews
        );
        
        return campaignId;
    }
    
    /**
     * @notice Inicia uma campanha após o depósito dos fundos
     * @param campaignId ID da campanha
     */
    function startCampaign(uint256 campaignId) external onlyBrand(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        
        require(campaign.status == CampaignStatus.Created, "CampaignManager: campaign is not in created state");
        require(block.timestamp < campaign.deadline, "CampaignManager: campaign deadline has passed");
        
        // Solicita o depósito dos fundos no PaymentVault
        IERC20 usdc = IERC20(paymentVault.usdcToken());
        require(
            usdc.allowance(msg.sender, address(paymentVault)) >= campaign.totalValue,
            "CampaignManager: insufficient USDC allowance"
        );
        
        // Deposita os fundos no PaymentVault
        paymentVault.depositFunds(campaignId, campaign.brand, campaign.totalValue);
        
        // Atualiza o status da campanha para ativa
        campaign.status = CampaignStatus.Active;
        
        emit CampaignStarted(campaignId);
    }
    
    /**
     * @notice Atualiza as métricas de uma campanha (chamado pelo OracleConnector)
     * @param campaignId ID da campanha
     * @param likes Número atual de likes
     * @param views Número atual de views
     */
    function updateMetrics(uint256 campaignId, uint256 likes, uint256 views) external onlyOracle {
        Campaign storage campaign = campaigns[campaignId];
        
        require(campaign.status == CampaignStatus.Active, "CampaignManager: campaign is not active");
        require(block.timestamp <= campaign.deadline, "CampaignManager: campaign has expired");
        
        // Atualiza as métricas da campanha
        campaign.currentLikes = likes;
        campaign.currentViews = views;
        
        emit MetricsUpdated(campaignId, likes, views);
        
        // Verifica se alguma milestone foi atingida
        checkMilestones(campaignId);
        
        // Verifica se a campanha foi concluída
        if ((campaign.targetLikes > 0 && likes >= campaign.targetLikes) && 
            (campaign.targetViews > 0 && views >= campaign.targetViews)) {
            completeCampaign(campaignId);
        }
    }
    
    /**
     * @notice Verifica se alguma milestone foi atingida e libera pagamento
     * @param campaignId ID da campanha
     */
    function checkMilestones(uint256 campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        
        // Calcula o progresso atual (média ponderada entre likes e views)
        uint256 likesProgress = campaign.targetLikes > 0 
            ? (campaign.currentLikes * 100) / campaign.targetLikes 
            : 0;
            
        uint256 viewsProgress = campaign.targetViews > 0 
            ? (campaign.currentViews * 100) / campaign.targetViews 
            : 0;
            
        // Calcula o progresso geral (média simples se ambos os targets estiverem definidos)
        uint256 overallProgress;
        if (campaign.targetLikes > 0 && campaign.targetViews > 0) {
            overallProgress = (likesProgress + viewsProgress) / 2;
        } else if (campaign.targetLikes > 0) {
            overallProgress = likesProgress;
        } else {
            overallProgress = viewsProgress;
        }
        
        // Define os níveis de milestone (25%, 50%, 75%, 100%)
        uint256[] memory milestoneThresholds = new uint256[](4);
        milestoneThresholds[0] = 25;
        milestoneThresholds[1] = 50;
        milestoneThresholds[2] = 75;
        milestoneThresholds[3] = 100;
        
        // Calcula o valor a ser pago por milestone
        uint256 valuePerMilestone = campaign.totalValue / 4;
        
        // Verifica cada milestone
        for (uint256 i = 0; i < milestoneThresholds.length; i++) {
            uint256 milestonePayment = (i + 1) * valuePerMilestone;
            
            // Se o progresso atingiu o threshold e o pagamento ainda não foi feito
            if (overallProgress >= milestoneThresholds[i] && campaign.paidAmount < milestonePayment) {
                uint256 paymentAmount = milestonePayment - campaign.paidAmount;
                
                // Atualiza o valor pago
                campaign.paidAmount = milestonePayment;
                
                // Libera o pagamento
                paymentVault.releasePayment(campaignId, campaign.creator, paymentAmount);
                
                emit MilestoneAchieved(campaignId, paymentAmount);
            }
        }
    }
    
    /**
     * @notice Marca uma campanha como concluída
     * @param campaignId ID da campanha
     */
    function completeCampaign(uint256 campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        
        // Atualiza o status da campanha para concluída
        campaign.status = CampaignStatus.Completed;
        
        // Garante que todo o valor seja pago
        if (campaign.paidAmount < campaign.totalValue) {
            uint256 remainingAmount = campaign.totalValue - campaign.paidAmount;
            campaign.paidAmount = campaign.totalValue;
            
            // Libera o pagamento restante
            paymentVault.releasePayment(campaignId, campaign.creator, remainingAmount);
        }
        
        emit CampaignCompleted(campaignId);
    }
    
    /**
     * @notice Cancela uma campanha (apenas a marca pode cancelar)
     * @param campaignId ID da campanha
     */
    function cancelCampaign(uint256 campaignId) external onlyBrand(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        
        require(campaign.status == CampaignStatus.Created || campaign.status == CampaignStatus.Active, 
                "CampaignManager: campaign cannot be cancelled");
        
        // Atualiza o status da campanha para cancelada
        campaign.status = CampaignStatus.Cancelled;
        
        emit CampaignCancelled(campaignId);
    }
    
    /**
     * @notice Marca uma campanha como expirada se o prazo foi atingido
     * @param campaignId ID da campanha
     */
    function expireCampaign(uint256 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        
        require(campaign.status == CampaignStatus.Active, "CampaignManager: campaign is not active");
        require(block.timestamp > campaign.deadline, "CampaignManager: campaign deadline has not passed");
        
        // Atualiza o status da campanha para expirada
        campaign.status = CampaignStatus.Expired;
        
        // Verifica se há pagamentos pendentes com base no progresso atual
        checkMilestones(campaignId);
        
        emit CampaignExpired(campaignId);
    }
    
    /**
     * @notice Retorna informações detalhadas de uma campanha
     * @param campaignId ID da campanha
     * @return Informações da campanha
     */
    function getCampaignDetails(uint256 campaignId) external view returns (Campaign memory) {
        return campaigns[campaignId];
    }
}