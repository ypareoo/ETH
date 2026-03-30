#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <string>
#include <thread>
#include <atomic> // Pour la variable thread-safe keepSniffing

QT_BEGIN_NAMESPACE
namespace Ui { class MainWindow; }
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

signals:
    void packetSent(const QString &message);

    // Signal émis quand une trame valide est reçue
    void packetReceived(QString time, QString src, QString dst, QString type, QString data);
    // Pour les messages simples ou erreurs (un seul texte)
    void snifferError(QString message);

private slots:
    void on_pushButton_clicked();
    void updateStatus(const QString &message);
    void on_pushButtonSavePayload_clicked();
    void on_SendFilepushButton_clicked();

    // NOUVEAU : Slot pour mettre à jour l'interface
    void updateMessageLabel(const QString &payload);
    void updateTable(QString time, QString src, QString dst, QString type, QString data);

private:
    std::string lastReceivedPayload; // Stockage propre de la donnée brute
    Ui::MainWindow *ui;
    void sendRawPacket(const std::string& payload);

    // NOUVEAUTÉS POUR LE RECEVEUR
    void sniffPackets(); // La fonction qui tournera en boucle
    std::thread snifferThread; // L'objet thread
    std::atomic<bool> keepSniffing; // Drapeau pour arrêter le thread proprement
};

std::vector<uint8_t> hexStringToBytes(const std::string& hex);
#endif // MAINWINDOW_H
