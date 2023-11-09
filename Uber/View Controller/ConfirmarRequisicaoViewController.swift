//
//  ConfirmarRequisicaoViewController.swift
//  Uber
//
//  Created by Rafaella Rodrigues Santos on 02/11/23.
//

import UIKit
import MapKit
import FirebaseDatabase
import FirebaseAuth

class ConfirmarRequisicaoViewController: UIViewController, CLLocationManagerDelegate {
    
    var nomePassageiro = ""
    var emailPassageiro = ""
    var localPassageiro = CLLocationCoordinate2D()
    var localMotorista = CLLocationCoordinate2D()
    var localDestino = CLLocationCoordinate2D()
    var status: StatusCorrida = .EmRequisicao
    var gerenciadorLocalizacao = CLLocationManager()

    @IBOutlet weak var mapa: MKMapView!
    @IBOutlet weak var botaoAceitarCorrida: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        gerenciadorLocalizacao.delegate = self
        gerenciadorLocalizacao.desiredAccuracy = kCLLocationAccuracyBest //precisao do posicionamento do usuario//queremos que a precisão seja a melhor possivel
        gerenciadorLocalizacao.requestWhenInUseAuthorization()
        gerenciadorLocalizacao.startUpdatingLocation()
        gerenciadorLocalizacao.allowsBackgroundLocationUpdates = true
        
        //Configurar área inicial do mapa
        let regiao = MKCoordinateRegion.init(center: self.localPassageiro, latitudinalMeters: 200, longitudinalMeters: 200)
        mapa.setRegion(regiao, animated: true)
        
        //Adiciona anotacao para o passageiro
        let anotacaoPassageiro = MKPointAnnotation()
        anotacaoPassageiro.coordinate = self.localPassageiro
        anotacaoPassageiro.title = self.nomePassageiro
        mapa.addAnnotation(anotacaoPassageiro)
        
        //Recupera status e ajusta a interface
        let database = Database.database().reference()
        let requisicoes = database.child("requisicoes")
        let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
        
        consultaRequisicoes.observe(.childChanged) { snapshot in
            
            if let dados = snapshot.value as? [String: Any] {
                if let statusR = dados["status"] as? String {
                    self.recarregarTelaStatus(status: statusR, dados: dados)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        //Recupera status e ajusta a interface
        let database = Database.database().reference()
        let requisicoes = database.child("requisicoes")
        let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
        
        consultaRequisicoes.observeSingleEvent(of: .childAdded) { snapshot in
            
            if let dados = snapshot.value as? [String: Any] {
                if let statusR = dados["status"] as? String {
                    self.recarregarTelaStatus(status: statusR, dados: dados)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let coordenadas = manager.location?.coordinate {
            self.localMotorista = coordenadas
            self.atualizarLocalMotorista()
        }
    }
    
    func recarregarTelaStatus(status: String, dados: [String: Any]) {
        
        //Carregar tela baseado nos status
        if status == StatusCorrida.PegarPassageiro.rawValue {
            print("status: Pegar Passageiro")
            self.pegarPassageiro()
           
            self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localPassageiro, tPartida: "Meu local", tDestino: "Passageiro")
            
        } else if(status == StatusCorrida.IniciarViagem.rawValue) {
            print("status: Iniciar Viagem")
            self.status = .IniciarViagem
            self.alternaBotaoIniciarViagem()
            
            //Recupera local de destino
            if let latDestino = dados["destinoLatitude"] as? Double {
                if let longDestino = dados["destinoLongitude"] as? Double{
                    
                    //Configura local de destino
                    self.localDestino = CLLocationCoordinate2D(latitude: latDestino, longitude: longDestino)
                }
            }
            
            //Exibir motorista destino
            self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localDestino, tPartida: "Motorista", tDestino: "Passageiro")
            
        }else if (status == StatusCorrida.EmViagem.rawValue) {
            
            //Altera o status
            self.status = .EmViagem
            
            //Alterna botao
            self.alternaBotaoPendenteFinalizarViagem()
            
            //Atualizar local motorista e passageiro
            
            //Recupera local de destino
            if let latDestino = dados["destinoLatitude"] as? Double {
                if let longDestino = dados["destinoLongitude"] as? Double{
                    
                    //Configura local de destino
                    self.localDestino = CLLocationCoordinate2D(latitude: latDestino, longitude: longDestino)
                    
                    //Exibir motorista passageiro
                    self.exibeMotoristaPassageiro(lPartida: self.localPassageiro, lDestino: self.localDestino, tPartida: "Motorista", tDestino: "Destino")
                }
            }
        }else if(status == StatusCorrida.ViagemFinalizada.rawValue) {
            self.status = .ViagemFinalizada
            if let preco = dados["precoViagem"] as? Double {
                self.alternaBotaoViagemFinalizada(preco: preco)
            }
        }
    }
    
    func atualizarLocalMotorista() {
        
        //Atualiza localizacao do motorista no Firebase
        let database = Database.database().reference()
        if self.emailPassageiro != "" {
            
            let requisicoes = database.child("requisicoes")
            let consultaRequisicao = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: emailPassageiro)
            
            consultaRequisicao.observeSingleEvent(of: .childAdded) { snapshot in
                
                if let dados = snapshot.value as? [String: Any] {
                    if let statusR = dados["status"] as? String{
                        
                        //Status PegarPassageiro
                        if statusR ==  StatusCorrida.PegarPassageiro.rawValue {
                            
                            //Verifica se o motorista esta proximo, para iniciar a corrida
                            let motoristaLocation = CLLocation(latitude: self.localMotorista.latitude, longitude: self.localMotorista.longitude)
                            
                            let passageiroLocation = CLLocation(latitude: self.localPassageiro.latitude, longitude: self.localPassageiro.longitude)
                            
                            //Calcula distancia entre motorista e passageiro
                            let distancia = motoristaLocation.distance(from: passageiroLocation)
                            let distanciaKM = distancia / 1000
                            
                           
                            if distanciaKM <= 0.1{
                               //Atualizar status
                                self.atualizarStatusRequisicao(status: StatusCorrida.IniciarViagem.rawValue)
                            }
                            
                        }else if(statusR == StatusCorrida.IniciarViagem.rawValue) {
                            
                            //self.alternaBotaoIniciarViagem()
                            
                            //Exibir motorista passageiro
                            self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localPassageiro, tPartida: "Motorista", tDestino: "Passageiro")
                            
                          }else if(statusR == StatusCorrida.EmViagem.rawValue) {
                              if let latDestino = dados["destinoLatitude"] as? Double{
                                  if let longDestino = dados["destinoLongitude"] as? Double{
                                      
                                      self.localDestino = CLLocationCoordinate2D(latitude: latDestino, longitude: longDestino)
                                      
                                      //Exibir motorista destino
                                      self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localDestino, tPartida: "Motorista", tDestino: "Destino")
                                  }
                              }
                          }
                    }
                    
                    let dadosMotorista = [
                        "motoristaLatitude": self.localMotorista.latitude,
                        "motoristaLongitude": self.localMotorista.longitude,
                    ] as [String : Any]
                    
                    //Salvar dados no firebase
                    snapshot.ref.updateChildValues(dadosMotorista)
                    
                }
            }
        }
    }
    
    @IBAction func aceitarCorrida(_ sender: Any) {
        
        if self.status == StatusCorrida.EmRequisicao {
            //Atualizar a requisicao
            let database = Database.database().reference()
            let autenticacao = Auth.auth()
            let requisicoes = database.child("requisicoes")
            
            if let emailMotorista = autenticacao.currentUser?.email{
                requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro).observeSingleEvent(of: .childAdded) { snapshot in
                    
                    let dadosMotorista = [
                        "motoristaEmail": emailMotorista,
                        "motoristaLatitude": self.localMotorista.latitude,
                        "motoristaLongitude": self.localMotorista.longitude,
                        "status": StatusCorrida.PegarPassageiro.rawValue
                    ] as [String : Any]
                    snapshot.ref.updateChildValues(dadosMotorista)
                    self.pegarPassageiro()
                }
            }
                //Exibir caminho para o passageiro no mapa
                let pasageiroCLL = CLLocation(latitude: self.localPassageiro.latitude, longitude: self.localPassageiro.longitude)
                CLGeocoder().reverseGeocodeLocation(pasageiroCLL) { local, erro in
                    
                    if erro == nil{
                       if let dadosLocal = local?.first {
                            let placeMark = MKPlacemark(placemark: dadosLocal)
                           let mapaItem = MKMapItem(placemark: placeMark)
                           mapaItem.name = self.nomePassageiro
                           
                           let opcoes = [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving]
                           mapaItem.openInMaps(launchOptions: opcoes )
                        }
                    }
                }
        }else if(self.status == StatusCorrida.IniciarViagem) {
            self.iniciarViagemDestino()
        }else if(self.status == StatusCorrida.EmViagem) {
            self.finalizarViagem()
        }
    }
    
    func finalizarViagem () {
        
        //Altera status
        self.status = .ViagemFinalizada
        
        //Calcula preco da viagem
        let precoKM: Double = 4
        
        //Recupera dados para atualizar preco
        let database = Database.database().reference()
        let requisicoes = database.child("requisicoes")
        let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
        
        consultaRequisicoes.observeSingleEvent(of: .childAdded) { snapshot in
            if let dados = snapshot.value as? [String: Any] {
                if let latI = dados["latitude"] as? Double{
                    if let longI = dados["longitude"] as? Double{
                        if let longD = dados["destinoLongitude"] as? Double{
                            if let latD = dados["destinoLatitude"] as? Double{
                                
                                let inicioLocation = CLLocation(latitude: latI, longitude: longI)
                                
                                let destinoLocation = CLLocation(latitude: latD, longitude: longD)
                                
                                //calcular distancia
                                let distancia = inicioLocation.distance(from: destinoLocation)
                                let distanciaKM = distancia / 1000
                                let precoViagem =  distanciaKM * precoKM
                                
                                let dadosAtualizar = [
                                    "precoViagem": precoViagem,
                                    "distanciaPercorrida": distanciaKM
                                ]
                                
                                snapshot.ref.updateChildValues(dadosAtualizar)
                                
                                //Atualiza requisicao no Firebase
                                self.atualizarStatusRequisicao(status: self.status.rawValue)
                                
                                //Alterna para viagem finalizada
                                self.alternaBotaoViagemFinalizada(preco: precoViagem)
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func iniciarViagemDestino() {
        
        //Altera status
        self.status = .EmViagem
        
        //Atualizar requisicao no Firebase
        self.atualizarStatusRequisicao(status: self.status.rawValue)
        
        //Exibir caminho para o destino no mapa
        let destinoCLL = CLLocation(latitude: localDestino.latitude, longitude: localDestino.longitude)
        
        CLGeocoder().reverseGeocodeLocation(destinoCLL) { local, erro in
            
            if erro == nil{
               if let dadosLocal = local?.first {
                    let placeMark = MKPlacemark(placemark: dadosLocal)
                   let mapaItem = MKMapItem(placemark: placeMark)
                   mapaItem.name = "Destino passageiro"
                   
                   let opcoes = [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving]
                   mapaItem.openInMaps(launchOptions: opcoes )
                }
            }
        }
    }
    
    func pegarPassageiro() {
        
        //Alterar o status
        self.status = .PegarPassageiro
        
        //Alterna botao
        self.alternaBotaoPegarPassageiro()
    }
        
    func alternaBotaoPegarPassageiro () {
        self.botaoAceitarCorrida.setTitle("A caminho do passageiro", for: .normal)
        self.botaoAceitarCorrida.isEnabled = false
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
    }
    
    func alternaBotaoViagemFinalizada (preco: Double) {
        self.botaoAceitarCorrida.isEnabled = false
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
        
        //Formata numero
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "pt_BR")
        let precoFinal = nf.string(from: NSNumber(value: preco))
        
        self.botaoAceitarCorrida.setTitle("Viagem finalizada - R$ " + precoFinal!, for: .normal)
    }
    
    func alternaBotaoIniciarViagem () {
        self.botaoAceitarCorrida.setTitle("Iniciar Viagem", for: .normal)
        self.botaoAceitarCorrida.isEnabled = true
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
    }
    
    func alternaBotaoPendenteFinalizarViagem () {
        self.botaoAceitarCorrida.setTitle("Finalizar Viagem", for: .normal)
        self.botaoAceitarCorrida.isEnabled = true
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
    }
       
    func exibeMotoristaPassageiro(lPartida: CLLocationCoordinate2D, lDestino: CLLocationCoordinate2D, tPartida: String, tDestino: String) {
        
        //Exibir passageiro e motorista no mapa
        mapa.removeAnnotations(mapa.annotations)
        
        let latDiferenca = abs(lPartida.latitude - lDestino.latitude) * 300000
        let longDiferenca = abs(lPartida.longitude - lDestino.longitude) * 300000
        
        let regiao = MKCoordinateRegion.init(center: lPartida, latitudinalMeters: latDiferenca, longitudinalMeters: longDiferenca)
        mapa.setRegion(regiao, animated: true)
        
        //Anotacao partida
        let anotacaoPartida = MKPointAnnotation()
        anotacaoPartida.coordinate = lPartida
        anotacaoPartida.title = tPartida
        mapa.addAnnotation(anotacaoPartida)
        
        //Anotacao Destino
        let anotacaoDestino = MKPointAnnotation()
        anotacaoDestino.coordinate = lDestino
        anotacaoDestino.title = tDestino
        mapa.addAnnotation(anotacaoDestino)
    }
    
    func atualizarStatusRequisicao(status: String) {
        
        if status != "" && self.emailPassageiro != "" {
            
            let database = Database.database().reference()
            let requisicoes = database.child("requisicoes")
            let consultaRequisicao = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
            
            consultaRequisicao.observeSingleEvent(of: .childAdded) { snapshot in
                
                if let dados = snapshot.value as? [String: Any] {
                    let dadosAtualizar = [
                        "status" : status
                    ]
                    
                    snapshot.ref.updateChildValues(dadosAtualizar)
                }
            }
        }
    }
}
    
    

