#!/bin/bash

# Authenticate using Managed Identity
echo "🔄 Authenticating with Azure..."
if ! az login --use-device-code; then
    echo "❌ ERROR: Failed to authenticate with Azure."
    exit 1
fi

# Fetch subscription ID dynamically
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

# Set Azure subscription
echo "🔄 Setting Azure subscription..."
if ! az account set --subscription "$SUBSCRIPTION_ID"; then
    echo "❌ ERROR: Failed to set subscription."
    exit 1
fi
echo "✅ Azure subscription set successfully."

# Fetch all available Cosmos DB regions
echo "🔄 Retrieving Cosmos DB locations..."
REGIONS=($(az cosmosdb list --query "[].location" -o tsv))

if [ ${#REGIONS[@]} -eq 0 ]; then
    echo "❌ ERROR: No Cosmos DB regions found."
    exit 1
fi

echo "✅ Retrieved Cosmos DB regions: ${REGIONS[*]}"
VALID_REGIONS=()

# Check quota for each region
for REGION in "${REGIONS[@]}"; do
    echo "----------------------------------------"
    echo "🔍 Checking region: $REGION"

    # Fetch quota details for Cosmos DB
    QUOTA_INFO=$(az cosmosdb show-usage --location "$REGION" --query "[?name=='TotalRequestUnits'].{Used:currentValue, Limit:limit}" -o json)

    if [ -z "$QUOTA_INFO" ] || [ "$QUOTA_INFO" == "[]" ]; then
        echo "⚠️ WARNING: No quota information found for $REGION. Skipping."
        continue
    fi

    # Extract used and limit values
    USED=$(echo "$QUOTA_INFO" | awk -F': ' '/"Used"/ {print $2}' | tr -d ',' | tr -d ' ')
    LIMIT=$(echo "$QUOTA_INFO" | awk -F': ' '/"Limit"/ {print $2}' | tr -d ',' | tr -d ' ')

    USED=${USED:-0}
    LIMIT=${LIMIT:-0}

    USED=$(echo "$USED" | cut -d'.' -f1)
    LIMIT=$(echo "$LIMIT" | cut -d'.' -f1)

    AVAILABLE=$((LIMIT - USED))

    echo "✅ Cosmos DB | Used: $USED | Limit: $LIMIT | Available: $AVAILABLE"

    # Check if quota is sufficient (you can change the threshold as needed)
    if [ "$AVAILABLE" -gt 0 ]; then
        echo "✅ Cosmos DB has enough quota in $REGION."
        VALID_REGIONS+=("$REGION")
    else
        echo "❌ ERROR: Cosmos DB in $REGION has insufficient quota."
    fi
done

# Determine final result
if [ ${#VALID_REGIONS[@]} -eq 0 ]; then
    echo "❌ No region with sufficient Cosmos DB quota found. Blocking deployment."
    exit 1
else
    echo "✅ Suggested Regions: ${VALID_REGIONS[*]}"
    exit 0
fi
