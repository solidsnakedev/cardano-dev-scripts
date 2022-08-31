
#--------- Set the customize color for echo function ---------
# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White
Reset='\e[0m'

echo_green(){
  echo -e "${IGreen}$1${Reset}"
}
echo_red(){
  echo -e "${IRed}$1${Reset}"
}
echo_yellow(){
  echo -e "${IYellow}$1${Reset}"
}
info(){
  echo -e "${IGreen}[INFO] $1${Reset}"
}
error(){
  echo -e "${IRed}[ERROR] $1${Reset}"
}
debug(){
  echo -e "${ICyan}[DEBUG] $1${Reset}"
}


#--------- Set the Path to your folders and binaries ---------
key_path="/node/keys"
script_path="/node/scripts"
data_path="/node/data"
config_path="/node/configuration"
transaction_path="/node/transactions"
cardano_script_path="/usr/local/bin"
cardanocli="/usr/local/bin/cardano-cli"
cardanonode="/usr/local/bin/cardano-node"

#--------- Helper functions ---------

generate_UTXO() #Parameter1=Address
{
    #--------- Query utxos and save it in fullUtxo.out ---------
    local wallet="${1}"
    ${cardanocli} query utxo \
        --address $(cat ${key_path}/${wallet}.addr) \
        --testnet-magic ${TESTNET_MAGIC} > ${data_path}/fullUtxo.out

    #--------- Remove 3 first rows, and sort balance ---------
    tail -n +3 ${data_path}/fullUtxo.out | sort -k3 -nr > ${data_path}/balance.out

    #--------- Read balance.out file and compose utxo inputs ---------
    local tx_in=""
    local total_balance=0
    local native_assets=""
    while read -r utxo; do
        in_addr=$(awk '{ print $1 }' <<< "${utxo}")
        idx=$(awk '{ print $2 }' <<< "${utxo}")
        utxo_balance=$(awk '{ print $3 }' <<< "${utxo}")
        assets=$(awk '{for(i=6;i<=(NF-2);i++) printf("%s ", $i)}' <<< "${utxo}") # Extract all native assets from colum 6 up to second last column
        native_assets="${native_assets}${assets}"
        total_balance=$((total_balance+utxo_balance))
        tx_in="${tx_in} --tx-in ${in_addr}#${idx}"
    done < ${data_path}/balance.out
    txcnt=$(cat ${data_path}/balance.out | wc -l)
    echo "${total_balance}"
    echo "${tx_in}"
    echo "${txcnt}"
    echo "${native_assets}"
}

generate_UTXO_Json()  #Parameter1=RawUTXO, Parameter2=Address
{

  #Convert given bech32 address into a base16(hex) address, not needed in theses scripts, but to make a true 1:1 copy of the normal UTXO JSON output
  #local utxoAddress=$(${cardanocli} address info --address ${2} 2> /dev/null | jq -r .base16); if [[ $? -ne 0 ]]; then local utxoAddress=${2}; fi
  local utxoAddress=${2}
  local utxoJSON="{" #start with a blank JSON skeleton and an open {

  while IFS= read -r line; do
  IFS=' ' read -ra utxo_entry <<< "${line}" # utxo_entry array holds entire utxo string

  local utxoHashIndex="${utxo_entry[0]}#${utxo_entry[1]}"

  #There are lovelaces on the UTXO -> check if the name is "lovelace" or if there are just 3 arguments
  if [[ "${utxo_entry[3]}" == "lovelace" ]] || [[ ${#utxo_entry[@]} -eq 3 ]]; then
                                                local idx=5; #normal indexstart for the next checks
                                                local utxoAmountLovelaces=${utxo_entry[2]};
                                              else
                                                local idx=2; #earlier indexstart, because no lovelaces present
                                                local utxoAmountLovelaces=0;
  fi

  #Build the entry for each UtxoHashIndex, start with the hash and the entry for the address and the lovelaces
  local utxoJSON+="\"${utxoHashIndex}\": { \"address\": \"${utxoAddress}\", \"value\": { \"lovelace\": \"${utxoAmountLovelaces}\""

  #value part is open
  local value_open=true

  local idxCompare=$(( ${idx} - 1 ))
  local old_asset_policy=""
  local policy_open=false

  #Add the Token entries if tokens available, also check for data (script) entries
  if [[ ${#utxo_entry[@]} -gt ${idxCompare} ]]; then # contains tokens

    while [[ ${#utxo_entry[@]} -gt ${idx} ]]; do  #check if there are more entries, and the amount is a number
      local next_entry=${utxo_entry[${idx}]}

      #if the next entry is a number -> process asset/tokendata
      if [[ "${next_entry}" =~ ^[0-9]+$ ]]; then
              local asset_amount=${next_entry}
              local asset_hash_name="${utxo_entry[$((idx+1))]}"
              IFS='.' read -ra asset <<< "${asset_hash_name}"
              local asset_policy=${asset[0]}

	      #Open up a policy if it is a different one
	      if [[ "${asset_policy}" != "${old_asset_policy}" ]]; then #open up a new policy
			if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; fi #close the previous policy first and remove the last , from the last assetname entry of the previous policy
			local utxoJSON="${utxoJSON}, \"${asset_policy}\": {"
			local policy_open=true
			local old_asset_policy=${asset_policy}
	      fi

              local asset_name=${asset[1]}
              #Add the Entry of the Token
	      local utxoJSON+="\"${asset_name}\": \"${asset_amount}\"," # the  , will be deleted when the policy part closes
              local idx=$(( ${idx} + 3 ))

     #if its a data entry, add the datumhash key-field to the json output
     elif [[ "${next_entry}" == "TxOutDatumHash" ]] && [[ "${utxo_entry[$((idx+1))]}" == *"Data"* ]]; then
	      if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; local policy_open=false; fi #close the previous policy first and remove the last , from the last assetname entry of the previous policy
	      if ${value_open}; then local utxoJSON+="}"; local value_open=false; fi #close the open value part
              local data_entry_hash=${utxo_entry[$((idx+2))]}
	      #Add the Entry for the data(datumhash)
              local utxoJSON+=",\"datumhash\": \"${data_entry_hash//\"/}\""
              local idx=$(( ${idx} + 4 ))
     else
              local idx=$(( ${idx} + 1 ))
     fi
    done
  fi

  #close policy if still open
  if ${policy_open}; then local utxoJSON="${utxoJSON%?}}"; fi #close the previous policy first and remove the last char "," from the last assetname entry of the previous policy

  #close value part if still open
  if ${value_open}; then local utxoJSON+="}"; fi #close the open value part

  #close the utxo part
  local utxoJSON+="},"  #the last char "," will be deleted at the end

done < <(printf "${1}\n" | tail -n +3) #read in from parameter 1 (raw utxo) but cut first two lines

  #close the whole json but delete the last char "," before that. do it only if there are entries present (length>1), else return an empty json
  if [[ ${#utxoJSON} -gt 1 ]]; then echo "${utxoJSON%?}}"; else echo "{}"; fi;

}

filter_asset() #Parameter1=All native assets #Parameter2=Asset name in hex
{
  local native_assets=${1}
  local asset_name=${2}
  IFS="+"
  # Make an array with all native assets
  read -ra assets_array <<< "${native_assets}"

  # Loop and Save all arrays in one variable
  assets=$(
  for val in "${assets_array[@]}";
  do
   echo "$val" | xargs
  done
  )
  # Get token balance of the asset
  echo $assets | grep -w ${asset_name} | awk '{print $1}'
  # Get policy id plus asset name
  echo $assets | grep -w ${asset_name} | awk '{print $2}'
  # Get all the rest of the assets and concatenate them with "+", so it can be used in a transaction
  echo $assets | grep -wv ${asset_name} | sed -z 's/\n/+/g;s/+$/\n/'
}