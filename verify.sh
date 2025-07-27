#!/bin/bash

# Script para verificar todos os contratos do InfluNet na Base Sepolia
# Executa as verificações em sequência

echo "🔍 Iniciando verificação de todos os contratos..."
echo "================================================"

# Primeiro, compile os contratos
echo "🏗️  Compilando contratos..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ Erro na compilação dos contratos!"
    exit 1
fi

echo "✅ Contratos compilados com sucesso!"
echo ""

# Endereços dos contratos deployados
USCD_ADDRESS="0x0B971C4e62AB0eC19CaF3eBb0527e8A528fcAdD6"
PAYMENT_VAULT_ADDRESS="0xB457f5908dE044843C90aA1771D999dA8A9Bf3fD"
CAMPAIGN_MANAGER_ADDRESS="0xE7c3e1C1F678cDfE8651556F28c396A38CC88E8D"
ORACLE_CONNECTOR_ADDRESS="0x101De02821A2b148c49cd39d2182dB216C74DC5F"

# Configurações da rede Base Sepolia
BASE_SEPOLIA_CHAIN_ID=84532
BASE_SEPOLIA_VERIFIER_URL="https://api-sepolia.basescan.org/api"

# Substitua com sua API key do BaseScan
BASE_SCAN_API_KEY="3RDK2V44XIIIYD3WTRNDI3Z34474Y5AG9W"

echo "📋 Endereços carregados:"
echo "USDC: $USCD_ADDRESS"
echo "PaymentVault: $PAYMENT_VAULT_ADDRESS"
echo "CampaignManager: $CAMPAIGN_MANAGER_ADDRESS"
echo "OracleConnector: $ORACLE_CONNECTOR_ADDRESS"

# Função para verificar se o artefato existe
check_artifact() {
    local contract_path=$1
    local contract_name=$2
    
    if [ ! -f "out/${contract_name}.sol/${contract_name}.json" ]; then
        echo "❌ Artefato não encontrado para $contract_name"
        echo "   Procurando em: out/${contract_name}.sol/${contract_name}.json"
        echo "   Verifique se o contrato foi compilado corretamente"
        return 1
    fi
    return 0
}

echo ""
echo "🔧 [1/4] Verificando USDC..."
if check_artifact "src/USDC.sol" "USDC"; then
    forge verify-contract "$USCD_ADDRESS" "src/USDC.sol:USDC" \
        --chain $BASE_SEPOLIA_CHAIN_ID \
        --verifier etherscan \
        --etherscan-api-key "$BASE_SCAN_API_KEY" \
        --watch
else
    echo "❌ Pulando verificação do USDC devido a artefato não encontrado"
fi

echo ""
echo "🔧 [2/4] Verificando PaymentVault..."
if check_artifact "src/PaymentVault.sol" "PaymentVault"; then
    # Gerar constructor args para PaymentVault (recebe endereço do USDC)
    PAYMENT_VAULT_ARGS=$(cast abi-encode "constructor(address)" "$USCD_ADDRESS")
    echo "📝 Constructor args PaymentVault: $PAYMENT_VAULT_ARGS"

    forge verify-contract "$PAYMENT_VAULT_ADDRESS" "src/PaymentVault.sol:PaymentVault" \
        --chain $BASE_SEPOLIA_CHAIN_ID \
        --verifier etherscan \
        --etherscan-api-key "$BASE_SCAN_API_KEY" \
        --constructor-args "$PAYMENT_VAULT_ARGS" \
        --watch
else
    echo "❌ Pulando verificação do PaymentVault devido a artefato não encontrado"
fi

echo ""
echo "🔧 [3/4] Verificando CampaignManager..."
if check_artifact "src/CampaignManager.sol" "CampaignManager"; then
    # Gerar constructor args para CampaignManager (recebe endereço do PaymentVault)
    CAMPAIGN_MANAGER_ARGS=$(cast abi-encode "constructor(address)" "$PAYMENT_VAULT_ADDRESS")
    echo "📝 Constructor args CampaignManager: $CAMPAIGN_MANAGER_ARGS"

    forge verify-contract "$CAMPAIGN_MANAGER_ADDRESS" "src/CampaignManager.sol:CampaignManager" \
        --chain $BASE_SEPOLIA_CHAIN_ID \
        --verifier etherscan \
        --etherscan-api-key "$BASE_SCAN_API_KEY" \
        --constructor-args "$CAMPAIGN_MANAGER_ARGS" \
        --watch
else
    echo "❌ Pulando verificação do CampaignManager devido a artefato não encontrado"
fi

echo ""
echo "🔧 [4/4] Verificando OracleConnector..."
if check_artifact "src/OracleConnector.sol" "OracleConnector"; then
    forge verify-contract "$ORACLE_CONNECTOR_ADDRESS" "src/OracleConnector.sol:OracleConnector" \
        --chain $BASE_SEPOLIA_CHAIN_ID \
        --verifier etherscan \
        --etherscan-api-key "$BASE_SCAN_API_KEY" \
        --watch
else
    echo "❌ Pulando verificação do OracleConnector devido a artefato não encontrado"
fi

echo ""
echo "🎉 Processo de verificação concluído!"
echo "================================================"
echo "USDC: $USCD_ADDRESS"
echo "PaymentVault: $PAYMENT_VAULT_ADDRESS"
echo "CampaignManager: $CAMPAIGN_MANAGER_ADDRESS"
echo "OracleConnector: $ORACLE_CONNECTOR_ADDRESS"