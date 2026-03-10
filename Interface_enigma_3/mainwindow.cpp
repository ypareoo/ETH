#include "mainwindow.h"
#include "ui_mainwindow.h"

#include <fstream>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/ethernet.h>
#include <netpacket/packet.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>
#include <QRegularExpressionValidator>

std::vector<uint8_t> hexStringToBytes(const std::string& hex) {
    std::vector<uint8_t> bytes;
    for (size_t i = 0; i < hex.length(); i += 2) {
        std::string byteString = hex.substr(i, 2);
        uint8_t byte = (uint8_t) strtol(byteString.c_str(), nullptr, 16);
        bytes.push_back(byte);
    }
    return bytes;
}

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
    , keepSniffing(true) // On autorise le thread à tourner dès le départ
{
    ui->setupUi(this);

    // Connexion pour l'envoi
    connect(this, &MainWindow::packetSent, this, &MainWindow::updateStatus);

    // NOUVELLE CONNEXION : On relie la réception de la trame à l'interface
    connect(this, &MainWindow::packetReceived, this, &MainWindow::updateMessageLabel);

    // Cette règle (Regex) autorise uniquement 0-9, a-f et A-F
    QRegularExpression re("^[0-9a-fA-F]*$");
    QRegularExpressionValidator *validator = new QRegularExpressionValidator(re, this);

    // On applique le validateur au champ de texte (QLineEdit)
    ui->MACSourcelineEdit->setValidator(validator);
    ui->MACDestinationlineEdit->setValidator(validator);
    ui->EthertypelineEdit->setValidator(validator);
    ui->ReceptionMACDESTlineEdit->setValidator(validator);
    ui->ReceptionMACSRClineEdit->setValidator(validator);

    // Lancement immédiat du thread d'écoute en arrière-plan
    snifferThread = std::thread(&MainWindow::sniffPackets, this);
}

MainWindow::~MainWindow()
{
    // FERMETURE PROPRE : Crucial pour éviter un crash de Qt à la fermeture
    keepSniffing = false; // On dit à la boucle du thread de s'arrêter
    if (snifferThread.joinable()) {
        snifferThread.join(); // On attend que le thread finisse son cycle en cours
    }
    delete ui;
}


void MainWindow::on_pushButton_clicked()
{
    // 1. Récupération du texte
    std::string payload = ui->textEdit->toPlainText().toStdString();

    // 2. Sauvegarde dans le fichier texte
    std::ofstream fichier("payload.txt");
    if (fichier.is_open()) {
        fichier << payload;
        fichier.close();
    } else {
        ui->statusLabel->setText("Erreur : Impossible de créer le fichier !");
        return;
    }

    // 3. Préparation de l'interface
    ui->statusLabel->setText("Envoi en cours...");
    ui->pushButton->setEnabled(false); // On désactive le bouton pour éviter le double-clic

    // 4. MULTITHREADING : Création et lancement du thread secondaire
    // On passe "payload" en copie [payload] pour que le thread y ait accès
    std::thread senderThread([this, payload]() {
        this->sendRawPacket(payload);
    });

    // On détache le thread pour qu'il vive sa vie en arrière-plan sans bloquer Qt
    senderThread.detach();
}

// Fonction appelée via le Signal pour mettre à jour l'interface en toute sécurité
void MainWindow::updateStatus(const QString &message)
{
    ui->statusLabel->setText(message);
    ui->pushButton->setEnabled(true); // On réactive le bouton
}

// Fonction exécutée par le thread secondaire
void MainWindow::sendRawPacket(const std::string& payload)
{
    // On utilise les sockets RAW bruts (comme dans votre classe RawSender)
    int sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (sock < 0) {
        // Au lieu de modifier le label directment, on émet un signal !
        emit packetSent("Erreur : Création du socket (Avez-vous lancé avec sudo ?)");
        return;
    }

    struct ifreq ifr;
    std::memset(&ifr, 0, sizeof(ifr));
    std::strncpy(ifr.ifr_name, "enp3s0", IFNAMSIZ - 1); // <-- VERIFIEZ QUE C'EST LA BONNE INTERFACE

    if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) {
        ::close(sock);
        emit packetSent("Erreur : Interface réseau 'enp3s0' introuvable.");
        return;
    }

    struct sockaddr_ll sll;
    std::memset(&sll, 0, sizeof(sll));
    sll.sll_family = AF_PACKET;
    sll.sll_ifindex = ifr.ifr_ifindex;
    sll.sll_halen = ETH_ALEN;

    // Construction de la trame
    unsigned char frame[1515];
    //unsigned char mac_dest[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
    //unsigned char mac_src[]  = {0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB};
    //unsigned char eth_type[] = {0x88, 0xB5};

    std::vector<uint8_t> mac_dest_vector = hexStringToBytes(ui->MACDestinationlineEdit->text().toStdString());
    std::vector<uint8_t> mac_src_vector = hexStringToBytes(ui->MACSourcelineEdit->text().toStdString());
    std::vector<uint8_t> eth_type_vector = hexStringToBytes(ui->EthertypelineEdit->text().toStdString());

    // Vérifier que l'adresse MAC a bien 6 octets pour éviter un crash
    unsigned char mac_dest[6];
    unsigned char mac_src[6];
    unsigned char eth_type[6];
    if (mac_dest_vector.size() == 6) {
        std::memcpy(mac_dest, mac_dest_vector.data(), 6);
        std::memcpy(mac_src, mac_src_vector.data(), 6);
        std::memcpy(eth_type, eth_type_vector.data(), 6);

        // Vous pouvez maintenant l'utiliser dans votre trame :
        // std::memcpy(frame, mac_dest, 6);
    } else {
        emit packetSent("Erreur : L'adresse MAC doit contenir 12 caractères hexadécimaux.");
    }


    std::memcpy(frame, mac_dest, 6);
    std::memcpy(frame + 6, mac_src, 6);
    std::memcpy(frame + 12, eth_type, 2);

    size_t payload_len = payload.size();
    if (payload_len > 1499) payload_len = 1499; // Sécurité (un char est deja utilise pour le type de requete)
    if (ui->ChiffrageRadioButton->isChecked()){
        std::memcpy(frame + 14,"*",1);
    }
    else if (ui->DechiffrageradioButton->isChecked()){
        std::memcpy(frame + 14,"+",1);
    }
    else {
        emit packetSent("Veuillez sélectionner chiffrage ou déchiffrage");
        return;
    }
    //const char* chiffrage_char = (ui->ChiffrageRadioButton->isChecked()) ? "*" : "+";

    std::memcpy(frame + 15, payload.c_str(), payload_len);
    std::memcpy(sll.sll_addr, mac_dest, 6);

    size_t total_len = 15 + payload_len;

    // Envoi physique
    ssize_t sent = sendto(sock, frame, total_len, 0, (struct sockaddr*)&sll, sizeof(sll));
    ::close(sock);

    // Vérification et émission du statut vers l'interface graphique
    if (sent > 0) {
        emit packetSent("Succès : " + QString::number(sent) + " octets envoyés !");
    } else {
        emit packetSent("Erreur : L'envoi réseau a échoué.");
    }
}

// NOUVEAU SLOT : Mise à jour de l'interface graphique
void MainWindow::updateMessageLabel(const QString &payload)
{
    ui->MessageLabel->setText(payload);
}

// NOUVELLE FONCTION : Le thread secondaire de réception
void MainWindow::sniffPackets()
{
    int sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL)); //
    if (sock < 0) {
        emit packetReceived("Erreur : Socket RX (sudo requis)");
        return;
    }

    // Configuration du timeout à 2 secondes
    // Cela permet au recvfrom de se débloquer régulièrement pour vérifier 'keepSniffing'
    struct timeval tv;
    tv.tv_sec = 2;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv)); //

    struct ifreq ifr;
    std::memset(&ifr, 0, sizeof(ifr));
    std::strncpy(ifr.ifr_name, "enp3s0", IFNAMSIZ - 1); //
    if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) { //
        ::close(sock);
        emit packetReceived("Erreur IF RX");
        return;
    }

    struct sockaddr_ll sll;
    std::memset(&sll, 0, sizeof(sll));
    sll.sll_family = AF_PACKET;
    sll.sll_ifindex = ifr.ifr_ifindex;
    sll.sll_protocol = htons(ETH_P_ALL); //

    if (bind(sock, (struct sockaddr*)&sll, sizeof(sll)) < 0) { //
        ::close(sock);
        emit packetReceived("Erreur Bind RX");
        return;
    }

    unsigned char buffer[2048]; //
    struct sockaddr_ll src_addr;
    socklen_t addr_len = sizeof(src_addr);

    // BOUCLE INFINIE DU THREAD
    while (keepSniffing) {
        // recvfrom lit le paquet. S'il n'y a rien pendant 2s, il renvoie -1
        ssize_t data_size = recvfrom(sock, buffer, sizeof(buffer), 0, (struct sockaddr*)&src_addr, &addr_len); //

        if (data_size < 0) {
            continue; // Timeout atteint, on reboucle (ce qui permet de vérifier keepSniffing)
        }

        // On ignore ce que notre propre machine émet
        if (src_addr.sll_pkttype == PACKET_OUTGOING) continue; //

        if (data_size >= 14) { //
            // On vérifie l'adresse MAC (00:11:22:33:44:55)
            char a_enregistrer = 0;
            std::vector<uint8_t> mac_src_vector = hexStringToBytes(ui->ReceptionMACSRClineEdit->text().toStdString());
            std::vector<uint8_t> mac_dest_vector = hexStringToBytes(ui->ReceptionMACDESTlineEdit->text().toStdString());
            if (std::memcmp(buffer,mac_dest_vector.data(),6) == 0  && ui->ReceptionDSTcheckBox->isChecked() == 1){
                a_enregistrer = 1;
            }
            else if (std::memcmp(buffer + 6,mac_src_vector.data(),6) == 0  && ui->ReceptionSRCcheckBox->isChecked() == 1){
                a_enregistrer = 1;
            }
            else if (ui->ReceptionDSTcheckBox->isChecked() == 0 && ui->ReceptionSRCcheckBox->isChecked() == 0){
                a_enregistrer = 1;
            }
            else {
                a_enregistrer = 0;
            }
            if (a_enregistrer == 1)
            {
                uint32_t payload_len = data_size - 14; //

                // On extrait les octets du payload et on les convertit en QString
                QByteArray payloadBytes(reinterpret_cast<const char*>(buffer + 14), payload_len);
                QString textPayload = QString::fromUtf8(payloadBytes);

                // On prévient l'interface graphique qu'on a un nouveau message
                lastReceivedPayload = textPayload.toStdString(); // On stocke la donnée propre
                emit packetReceived(textPayload);
            }
        }
    }

    // Si keepSniffing passe à false (fermeture de l'app), on arrive ici et on ferme la prise
    ::close(sock);
}

void MainWindow::on_pushButtonSavePayload_clicked()
{
    // 1. Récupération du chemin
    //std::string path = ui->textEditFileNameSave->toPlainText().toStdString();
    std::string path = ui->lineEditFileNameSave->text().toStdString();

    //  Récupération du payload

    // 2. Sauvegarde dans le fichier texte
    std::ofstream fichier(path.c_str());
    if (fichier.is_open()) {
        fichier << lastReceivedPayload; //
        fichier.close();
        ui->ErrorSavelabel->setText("");
    } else {
        ui->ErrorSavelabel->setText("Erreur : Impossible de créer le fichier !");
        return;
    }
}
