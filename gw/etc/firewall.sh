#!/bin/sh
set -e

# Limpa regras anteriores
iptables -F
iptables -t nat -F
iptables -X

# Politica padrao: bloquear encaminhamento nao autorizado
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

# Permite retorno de conexoes ja estabelecidas ou relacionadas
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Internet (eth0) -> DMZ (eth1): apenas HTTP (web:80) e SSH (bastion:22) apos DNAT
iptables -A FORWARD -i eth0 -o eth1 -d 10.10.1.80 -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -d 10.10.1.22 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# LAN (eth2) -> DMZ (eth1) e Internet (eth0): administracao e saida da LAN
# DMZ -> LAN permanece bloqueada pela politica padrao FORWARD DROP
iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT

# DNAT: publica HTTP (80) e SSH (2222 -> 22) no IP publico do gw
iptables -t nat -A PREROUTING -i eth0 -d 203.0.113.1 -p tcp --dport 80 -j DNAT --to-destination 10.10.1.80:80
iptables -t nat -A PREROUTING -i eth0 -d 203.0.113.1 -p tcp --dport 2222 -j DNAT --to-destination 10.10.1.22:22

# MASQUERADE: LAN sai para a Internet mascarada com o IP publico do gw
iptables -t nat -A POSTROUTING -s 10.10.2.0/24 -o eth0 -j MASQUERADE
