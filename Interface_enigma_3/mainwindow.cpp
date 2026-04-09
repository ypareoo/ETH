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
#include <QNetworkInterface>
#include <QDateTime>


MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
    , keepSniffing(true) // On autorise le thread à tourner dès le départ
{
    ui->setupUi(this);

    ui->tableWidgetTrames->setColumnCount(5);
    ui->tableWidgetTrames->setHorizontalHeaderLabels({"Heure", "Source", "Destination", "Type", "Payload"});

    // Optionnel : étirer la dernière colonne pour prendre toute la place
    ui->tableWidgetTrames->horizontalHeader()->setSectionResizeMode(4, QHeaderView::Stretch);
    // Empêcher l'édition des cellules pour que ce soit une simple liste de log
    ui->tableWidgetTrames->setEditTriggers(QAbstractItemView::NoEditTriggers);


    // Connexion pour l'envoi pour le message sur l'interface
    connect(this, &MainWindow::packetSent, this, &MainWindow::updateStatus);

    // COnnexion pour la réception de la trame à l'interface

    connect(this, &MainWindow::snifferError, this, &MainWindow::updateMessageLabel);
    connect(this, &MainWindow::packetReceived, this, &MainWindow::updateTable);

    // Cette règle (Regex) autorise uniquement 0-9, a-f et A-F
    QRegularExpression re("^[0-9a-fA-F]*$");
    QRegularExpressionValidator *validator = new QRegularExpressionValidator(re, this);

    // On applique le validateur aux champs de texte (QLineEdit)
    ui->MACSourcelineEdit->setValidator(validator);
    ui->MACDestinationlineEdit->setValidator(validator);
    ui->EthertypelineEdit->setValidator(validator);
    ui->ReceptionMACDESTlineEdit->setValidator(validator);
    ui->ReceptionMACSRClineEdit->setValidator(validator);

    // On récupère toutes les interfaces réseau de la machine
    QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();

    for (const QNetworkInterface &iface : interfaces) {
        // Bonne pratique : On ne garde que les interfaces qui sont "Allumées" (IsUp)
        // et on ignore la boucle locale "lo" (IsLoopBack) si on ne veut pas se sniffer soi-même
        if (iface.flags().testFlag(QNetworkInterface::IsUp) &&
            !iface.flags().testFlag(QNetworkInterface::IsLoopBack)) {

            // On ajoute le nom technique (ex: "enp3s0", "eth0", "wlan0") à la liste
            ui->interfaceComboBox->addItem(iface.name());
        }
    }

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

    // 2. Sauvegarde dans le fichier texte (pas d'interêt à ce stade)
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

    // 1. On récupère le texte affiché dans la liste déroulante
    QString interfaceSelectionnee = ui->interfaceComboBox->currentText();

    // 2. On le convertit en std::string (car strncpy a besoin de C++)
    std::string nomInterface = interfaceSelectionnee.toStdString();

    struct ifreq ifr;
    std::memset(&ifr, 0, sizeof(ifr));
    std::strncpy(ifr.ifr_name, nomInterface.c_str(), IFNAMSIZ - 1);

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
    QByteArray mac_dest_vector = QByteArray::fromHex(ui->MACDestinationlineEdit->text().toUtf8());
    QByteArray mac_src_vector = QByteArray::fromHex(ui->MACSourcelineEdit->text().toUtf8());
    QByteArray eth_type_vector = QByteArray::fromHex(ui->EthertypelineEdit->text().toUtf8());

    // Vérifier que l'adresse MAC a bien 6 octets pour éviter un crash
    unsigned char mac_dest[6];
    unsigned char mac_src[6];
    unsigned char eth_type[6];
    if (mac_dest_vector.size() == 6 && mac_src_vector.size() == 6 && eth_type_vector.size() == 2) {
        std::memcpy(mac_dest, mac_dest_vector.data(), 6);
        std::memcpy(mac_src, mac_src_vector.data(), 6);
        std::memcpy(eth_type, eth_type_vector.data(), 2);

        // Vous pouvez maintenant l'utiliser dans votre trame :
        // std::memcpy(frame, mac_dest, 6);
    } else {
        emit packetSent("Erreur : L'adresse MAC doit contenir 12 caractères hexadécimaux.");
        return;
    }


    std::memcpy(frame, mac_dest, 6);
    std::memcpy(frame + 6, mac_src, 6);
    std::memcpy(frame + 12, eth_type, 2);

    size_t payload_len = payload.size();
    if (payload_len > 1499) payload_len = 1499; // Sécurité (un char est deja utilise pour le type de requete)
    /*if (ui->ChiffrageRadioButton->isChecked()){
        std::memcpy(frame + 14,"A",1);
    }
    else if (ui->DechiffrageradioButton->isChecked()){
        std::memcpy(frame + 14,"+",1);
    }
    else {
        emit packetSent("Veuillez sélectionner chiffrage ou déchiffrage");
        return;
    }*/
    //const char* chiffrage_char = (ui->ChiffrageRadioButton->isChecked()) ? "*" : "+";

    std::memcpy(frame + 14, payload.c_str(), payload_len);
    std::memcpy(sll.sll_addr, mac_dest, 6);

    size_t total_len = 14 + payload_len;

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

// SLOT : Mise à jour de l'interface graphique
void MainWindow::updateMessageLabel(const QString &payload)
{
    ui->MessageLabel->setText(payload);
}

void MainWindow::updateTable(QString time, QString src, QString dst, QString type, QString data)
{
    // Insérer une nouvelle ligne au début (index 0)
    ui->tableWidgetTrames->insertRow(0);

    // Remplir les cellules de la ligne
    ui->tableWidgetTrames->setItem(0, 0, new QTableWidgetItem(time));

    // Pour extraire les MAC, vous pouvez passer des arguments supplémentaires
    // à votre signal packetReceived(QString payload, QString src, QString dst)
    ui->tableWidgetTrames->setItem(0, 1, new QTableWidgetItem(src));
    ui->tableWidgetTrames->setItem(0, 2, new QTableWidgetItem(dst));
    ui->tableWidgetTrames->setItem(0, 3, new QTableWidgetItem(type));
    ui->tableWidgetTrames->setItem(0, 4, new QTableWidgetItem(data));

    // Nettoyage automatique
    if (ui->tableWidgetTrames->rowCount() > 500) {
        ui->tableWidgetTrames->removeRow(ui->tableWidgetTrames->rowCount() - 1);
    }
}



// thread secondaire de réception
void MainWindow::sniffPackets()
{
    //récupếration du nom de l'interface réseau
    QString interfaceSelectionnee = ui->interfaceComboBox->currentText();
    std::string nomInterface = interfaceSelectionnee.toStdString();

    int sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL)); //
    if (sock < 0) {
        emit snifferError("Erreur : Socket RX (sudo requis)");
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
    std::strncpy(ifr.ifr_name, nomInterface.c_str(), IFNAMSIZ - 1); //
    if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) { //
        ::close(sock);
        emit snifferError("Erreur IF RX");
        return;
    }

    struct sockaddr_ll sll;
    std::memset(&sll, 0, sizeof(sll));
    sll.sll_family = AF_PACKET;
    sll.sll_ifindex = ifr.ifr_ifindex;
    sll.sll_protocol = htons(ETH_P_ALL); //

    if (bind(sock, (struct sockaddr*)&sll, sizeof(sll)) < 0) { //
        ::close(sock);
        emit snifferError("Erreur Bind RX");
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
            char a_enregistrer = 1;
            QByteArray mac_src_vector = QByteArray::fromHex(ui->ReceptionMACSRClineEdit->text().toUtf8());
            QByteArray mac_dest_vector = QByteArray::fromHex(ui->ReceptionMACDESTlineEdit->text().toUtf8());


            if (mac_src_vector.size() != 6 || mac_dest_vector.size() != 6){
                QString msgerreur = "les adresse mac doivent avoir 6 octets";
                emit snifferError(msgerreur);
                continue;
            }
            else if (std::memcmp(buffer,mac_dest_vector.data(),6) != 0  && ui->ReceptionDSTcheckBox->isChecked() == 1){
                a_enregistrer = 0;
                QString msgerreur = "-";
                emit snifferError(msgerreur);
            }
            else if (std::memcmp(buffer + 6,mac_src_vector.data(),6) != 0  && ui->ReceptionSRCcheckBox->isChecked() == 1){
                a_enregistrer = 0;
                QString msgerreur = "-";
                emit snifferError(msgerreur);
            }
            if (a_enregistrer == 1)
            {



                uint32_t payload_len = data_size - 14;

                // On extrait les octets du payload et on les convertit en QString
                QByteArray payloadBytes(reinterpret_cast<const char*>(buffer + 14), payload_len);
                QString textPayload = QString::fromUtf8(payloadBytes);

                // On prévient l'interface graphique qu'on a un nouveau message
                lastReceivedPayload = textPayload.toStdString(); // On stocke la donnée propre

                // Conversion des MAC en texte lisible (ex: AA:BB:CC...)
                auto macToString = [](const unsigned char* m) {
                    return QString("%1:%2:%3:%4:%5:%6")
                    .arg(m[0], 2, 16, QChar('0')).arg(m[1], 2, 16, QChar('0'))
                        .arg(m[2], 2, 16, QChar('0')).arg(m[3], 2, 16, QChar('0'))
                        .arg(m[4], 2, 16, QChar('0')).arg(m[5], 2, 16, QChar('0')).toUpper();
                };

                QString strDst = macToString(buffer);
                QString strSrc = macToString(buffer + 6);
                QString strType = QString("0x%1").arg(((buffer[12] << 8) | buffer[13]), 4, 16, QChar('0')).toUpper();

                emit packetReceived(QDateTime::currentDateTime().toString("hh:mm:ss.zzz"),
                                    strSrc, strDst, strType, textPayload);

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

void MainWindow::on_SendFilepushButton_clicked(){
    std::string path = ui->FileNameSendlineEdit->text().toStdString();
    // 1. Ouverture en mode binaire (brut)
    std::ifstream fichier(path.c_str(), std::ios::binary);

    if (!fichier.is_open()) {
        emit packetSent("Erreur : Impossible d'ouvrir le fichier à lire.");
        return;
    }

    // La limite max de la charge utile
    const size_t TAILLE_MAX_PAYLOAD = 1499;

    std::vector<char> buffer(TAILLE_MAX_PAYLOAD);

    // 2. Boucle de lecture et d'envoi
    do {
        // On demande au flux de lire jusqu'à 1499 octets et de les mettre dans le buffer
        fichier.read(buffer.data(), TAILLE_MAX_PAYLOAD);

        // On interroge le flux : "Combien d'octets as-tu RÉELLEMENT lus lors de la dernière action ?"
        std::streamsize octetsLus = fichier.gcount();

        // S'il a lu des données
        if (octetsLus > 0) {

            // On crée notre payload en ne prenant QUE le nombre d'octets lus
            // Cela évite d'envoyer des "déchets" de la mémoire sur le dernier bloc
            std::string payload(buffer.data(), octetsLus);

            // On expédie ce bloc sur le réseau
            this->sendRawPacket(payload);

            // 1 milliseconde de pause entre chaque trame pour éviter de saturer la carte réseau
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        // La boucle s'arrête naturellement quand le fichier atteint la fin (EOF)
    } while (fichier);

    fichier.close();
    emit packetSent("Succès : Fichier entier envoyé par flux C++ !");
}
