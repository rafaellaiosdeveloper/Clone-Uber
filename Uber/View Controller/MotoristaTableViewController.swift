//
//  MotoristaTableViewController.swift
//  Uber
//
//  Created by Rafaella Rodrigues Santos on 31/10/23.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import MapKit

class MotoristaTableViewController: UITableViewController, CLLocationManagerDelegate {
    
    let autenticacao = Auth.auth()
    var listaRequisicoes: [DataSnapshot] = []
    var gerenciadorLocalizacao = CLLocationManager()
    var localMotorista = CLLocationCoordinate2D()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Configurar localizacao do motorista
        gerenciadorLocalizacao.delegate = self
        gerenciadorLocalizacao.desiredAccuracy = kCLLocationAccuracyBest //precisao do posicionamento do usuario//queremos que a precisão seja a melhor possivel
        gerenciadorLocalizacao.requestWhenInUseAuthorization()
        gerenciadorLocalizacao.startUpdatingLocation()
        
        //configura banco de dados
        let database = Database.database().reference()
        let requisicoes = database.child("requisicoes")
        
        //Recuperar requisicoes
        requisicoes.observe(.value) { snapshot in
            self.listaRequisicoes = []
            if snapshot.value != nil{
                for filho in snapshot.children {
                    self.listaRequisicoes.append(filho as! DataSnapshot)
                }
            }
            self.tableView.reloadData()
        }
        
        //Limpa requisicao caso usuario cancele
        requisicoes.observe(.childRemoved) { snapshot in
            var indice = 0
            for requisicao in self.listaRequisicoes {
                if requisicao.key == snapshot.key{
                    self.listaRequisicoes.remove(at: indice)
                }
                indice = indice + 1
            }
            
            self.tableView.reloadData()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let coordenadas = manager.location?.coordinate {
            self.localMotorista = coordenadas
        }
    }
    
    @IBAction func deslogarMotorista(_ sender: Any) {
        do{
            try autenticacao.signOut()
            dismiss(animated: true)
            print("sucesso")
        }catch{
            print("Erro ao deslogar usuario")
        }
    }
    
    // MARK: - Table view data source
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let snapshot = self.listaRequisicoes[indexPath.row]
        self.performSegue(withIdentifier: "segueAceitarCorrida", sender: snapshot)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "segueAceitarCorrida"{
            if let confirmarViewController = segue.destination as? ConfirmarRequisicaoViewController{
                
                if let snapshot = sender as? DataSnapshot {
                    if let dados = snapshot.value as? [String:Any] {
                        if let latPassageiro = dados["latitude"] as? Double {
                            if let lonPassageiro = dados["longitude"] as? Double {
                                if let nomePassageiro = dados["nome"] as? String {
                                    if let emailPassageiro = dados["email"] as? String {
                                        // Recupera os dados do Passageiro
                                        let localPassageiro = CLLocationCoordinate2D(latitude: latPassageiro, longitude: lonPassageiro)
                                        // Envia os dados para a próxima ViewController
                                        confirmarViewController.nomePassageiro = nomePassageiro
                                        confirmarViewController.emailPassageiro = emailPassageiro
                                        confirmarViewController.localPassageiro = localPassageiro
                                        // Envia os dados do motorista
                                        confirmarViewController.localMotorista = self.localMotorista
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.listaRequisicoes.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let celula = tableView.dequeueReusableCell(withIdentifier: "celulaMotorista", for: indexPath)
        
        let snapshot = self.listaRequisicoes[indexPath.row]
        if let dados = snapshot.value as? [String: Any] {
            
            if let latPassageiro = dados["latitude"] as? Double{
                if let longPassageiro = dados["longitude"] as? Double {
                    let motoristaLocation = CLLocation(latitude: self.localMotorista.latitude, longitude: self.localMotorista.longitude)
                    let passageiroLocation = CLLocation(latitude: latPassageiro, longitude: longPassageiro)
                    
                    let distanciaMetros = motoristaLocation.distance(from: passageiroLocation)
                    let distanciaKM = distanciaMetros / 1000
                    let distanciaFinal = round( distanciaKM )
                    
                    var requisicaoMotorista = ""
                    if let emailMotoristaR = dados["motoristaEmail"] as? String{
                        let autenticacao = Auth.auth()
                        if let emailMotoristaLogado = autenticacao.currentUser?.email {
                            if emailMotoristaR == emailMotoristaLogado {
                                requisicaoMotorista = "{ANDAMENTO}"
                                if let status = dados["status"] as? String {
                                    if status == StatusCorrida.ViagemFinalizada.rawValue {
                                        requisicaoMotorista = "{FINALIZADA}"
                                    }
                                }
                            }
                        }
                    }
                    
                    if let nomePassageiro = dados["nome"] as? String{
                        celula.textLabel?.text = "\(nomePassageiro) \(requisicaoMotorista)"
                        celula.detailTextLabel?.text = "\(distanciaFinal) KM de distância"
                    }
                }
            }
        }
        return celula
    }
}
