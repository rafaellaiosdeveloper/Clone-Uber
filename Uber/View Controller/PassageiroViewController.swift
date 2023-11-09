//
//  PassageiroViewController.swift
//  Uber
//
//  Created by Rafaella Rodrigues Santos on 30/10/23.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import MapKit

class PassageiroViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapa: MKMapView!
    @IBOutlet weak var botaoChamar: UIButton!
    @IBOutlet weak var areaEndereco: UIView!
    @IBOutlet weak var marcadorLocalPassageiro: UIView!
    @IBOutlet weak var marcadorLocalDestino: UIView!
    @IBOutlet weak var enderecoDestinoCampo: UITextField!
    
    let autenticacao = Auth.auth()
    let database = Database.database().reference()
    var gerenciadorLocalizacao = CLLocationManager()
    var localUsuario = CLLocationCoordinate2D()
    var localMotorista = CLLocationCoordinate2D()
    var uberChamado = false
    var uberACaminho = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        gerenciadorLocalizacao.delegate = self
        gerenciadorLocalizacao.desiredAccuracy = kCLLocationAccuracyBest //precisao do posicionamento do usuario//queremos que a precisão seja a melhor possivel
        gerenciadorLocalizacao.requestWhenInUseAuthorization()
        gerenciadorLocalizacao.startUpdatingLocation()
        
        //Configurar arredondamento dos marcadores
        self.marcadorLocalPassageiro.layer.cornerRadius = 7.5
        self.marcadorLocalPassageiro.clipsToBounds = true
        
        self.marcadorLocalDestino.layer.cornerRadius = 7.5
        self.marcadorLocalDestino.clipsToBounds = true
        
        self.areaEndereco.layer.cornerRadius = 10
        self.areaEndereco.clipsToBounds = true
        
        
        //Verifica se já tem uma requisicao de Uber
        let database = Database.database().reference()
        let autenticacao = Auth.auth()
        
        if let emailUsuario = autenticacao.currentUser?.email {
            
            let requisicoes = database.child("requisicoes")
            let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: emailUsuario)
            
            //Adicione ouvinte para quando usuario chamar Uber
            consultaRequisicoes.observe(.childAdded) { snapshot in
                if snapshot.value != nil{
                    self.alternaBotaoCancelarUber()
                }
            }
            
            //Adiciona ouvinte para quando motorista aceitar corrida
            consultaRequisicoes.observe(.childChanged) { snapshot in
                if let dados = snapshot.value as? [String: Any] {
                    if let status = dados["status"] as? String {
                        if status == StatusCorrida.PegarPassageiro.rawValue{
                            if let latMotorista = dados["motoristaLatitude"] {
                                if let longMotorista = dados["motoristaLongitude"] {
                                    self.localMotorista =
                                    CLLocationCoordinate2D(latitude: latMotorista as! CLLocationDegrees, longitude: longMotorista as! CLLocationDegrees)
                                    self.exibirMotoristaPassageiro()
                                }
                            }
                        }else if(status == StatusCorrida.EmViagem.rawValue) {
                            self.alternaBotaoEmViagem()
                        }else if(status == StatusCorrida.ViagemFinalizada.rawValue) {
                            if let preco = dados["precoViagem"] as? Double {
                                self.alternaBotaoViagemFinalizada(preco: preco)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func exibirMotoristaPassageiro() {
        
        self.uberACaminho = true
       
        //Calcular distancia entre motorista e passageiro
        let motoristaLocation = CLLocation(latitude: self.localMotorista.latitude, longitude: self.localMotorista.longitude)
        
        let passageiroLocation = CLLocation(latitude: self.localUsuario.latitude, longitude: self.localUsuario.longitude)
        
        //Calcula distancia entre motorista e passageiro
        var mensagem = ""
        let distancia = motoristaLocation.distance(from: passageiroLocation)
        let distanciaKM = distancia / 1000
        let distanciaFinal = round(distanciaKM)
        mensagem = "Motorista \(distanciaFinal) KM distante"
        
        if distanciaKM < 1{
            let distanciaM = round(distancia)
            mensagem = "Motorista \(distanciaM) M distante"
        }
        
        self.botaoChamar.backgroundColor = UIColor(red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
        self.botaoChamar.setTitle(mensagem, for: .normal)
        
        //Exibir passageiro e motorista no mapa
        mapa.removeAnnotations(mapa.annotations)
        
        let latDiferenca = abs(self.localUsuario.latitude - self.localMotorista.latitude) * 300000
        let longDiferenca = abs(self.localUsuario.longitude - self.localMotorista.longitude) * 300000
        let regiao = MKCoordinateRegion.init(center: self.localUsuario, latitudinalMeters: latDiferenca, longitudinalMeters: longDiferenca)
        mapa.setRegion(regiao, animated: true)
        
        //Anotacao motorista
        let anotacaoMotorista = MKPointAnnotation()
        anotacaoMotorista.coordinate = self.localMotorista
        anotacaoMotorista.title = "Motorista"
        mapa.addAnnotation(anotacaoMotorista)
        
        //Anotacao Passageiro
        let anotacaoPassageiro = MKPointAnnotation()
        anotacaoPassageiro.coordinate = self.localUsuario
        anotacaoPassageiro.title = "Passageiro"
        mapa.addAnnotation(anotacaoPassageiro)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {//para atualizacao da loc do usuario
        
        //Recupera as coordenadas do local atual
        if let coordenadas = manager.location?.coordinate {
            
            //Configura local atual do usuario
            self.localUsuario = coordenadas
            
            if self.uberACaminho{
                self.exibirMotoristaPassageiro()
            }else{
                let regiao = MKCoordinateRegion.init(center: coordenadas, latitudinalMeters: 200, longitudinalMeters: 200)
                mapa.setRegion(regiao, animated: true)
                
                //Remove anotacoes antes de criar
                mapa.removeAnnotations(mapa.annotations)
                
                //Cria uma anotacao para o local do usuario
                let anotacaoUsuario = MKPointAnnotation()
                anotacaoUsuario.coordinate = coordenadas
                anotacaoUsuario.title = "Seu Local"
                mapa.addAnnotation(anotacaoUsuario)
            }
        }
    }
    
    @IBAction func deslogarUsuario(_ sender: Any) {
        
        do{
                   try autenticacao.signOut()
            dismiss(animated: true)
                   print("sucesso")
                }catch{
                   print("Erro ao deslogar usuario")
               }
        }
    
    @IBAction func chamarUber(_ sender: Any) {
        
        let requisicao = database.child("requisicoes")
        if let emailUsuario = autenticacao.currentUser?.email{
            if self.uberChamado {//Uber chamado
                self.alternaBotaoChamarUber()
                
                //Remover requisicao
                let requisicao = database.child("requisicoes")

                requisicao.queryOrdered(byChild: "email").queryEqual(toValue: emailUsuario).observeSingleEvent(of: .childAdded, with: { (snapshot) in
                    snapshot.ref.removeValue()
                })//usar observador apenas uma vez
            }else{//Uber nao foi chamado
                self.salvarRequisicao()
            }//fim else
        }
    }
    
    func salvarRequisicao() {
        
        let requisicao = database.child("requisicoes")
        if let idUsuario = autenticacao.currentUser?.uid {
            if let emailUsuario = autenticacao.currentUser?.email{
                if let enderecoDestino = self.enderecoDestinoCampo.text{
                    if enderecoDestino != ""{
                        
                        CLGeocoder().geocodeAddressString(enderecoDestino) { local, erro in
                            if erro == nil{
                                if let dadosLocal = local?.first{
                                    
                                    var rua = ""
                                    if dadosLocal.thoroughfare != nil{
                                        rua = dadosLocal.thoroughfare!
                                    }
                                    
                                    var numero = ""
                                    if dadosLocal.subThoroughfare != nil{
                                        numero = dadosLocal.subThoroughfare!
                                    }
                                    
                                    var bairro = ""
                                    if dadosLocal.subLocality != nil{
                                        bairro = dadosLocal.subLocality!
                                    }
                                    
                                    var cidade = ""
                                    if dadosLocal.locality != nil{
                                        cidade = dadosLocal.locality!
                                    }
                                    
                                    var cep = ""
                                    if dadosLocal.postalCode != nil{
                                        cep = dadosLocal.postalCode!
                                    }
                                    
                                    let enderecoCompleto = "\(rua), \(numero), \(bairro) - \(cidade) - \(cep)"
                                    
                                    if let latDestino = dadosLocal.location?.coordinate.latitude{
                                        if let longDestino = dadosLocal.location?.coordinate.longitude{
                                            
                                            let alerta = UIAlertController(title: "Confirme seu endereço", message: enderecoCompleto, preferredStyle: .alert)
                                            
                                            let acaoCancelar = UIAlertAction(title: "Cancelar", style: .cancel)
                                            let acaoConfirmar = UIAlertAction(title: "Confirmar", style: .default) { alertAction in
                                                
                                                //Recuperar nome usuario
                                                let database = self.database.database.reference()
                                                let usuarios = database.child("usuarios").child(idUsuario)
                                                
                                                usuarios.observeSingleEvent(of: .value) { snapshot in
                                                    
                                                    let dados = snapshot.value as? NSDictionary
                                                    let nomeUsuario = dados!["nome"] as? String
                                                    
                                                    //Alternar para o botao de cancelar
                                                    self.alternaBotaoCancelarUber()
                                                    
                                                    //Salvar dados da requisicao
                                                    let dadosUsuario = [
                                                        "destinoLatitude" : latDestino,
                                                        "destinoLongitude": longDestino,
                                                        "email" : emailUsuario,
                                                        "nome" : nomeUsuario,
                                                        "latitude" : self.localUsuario.latitude,
                                                        "longitude" : self.localUsuario.longitude
                                                    ] as [String : Any]
                                                    requisicao.childByAutoId().setValue(dadosUsuario)
                                                    
                                                    self.alternaBotaoCancelarUber()
                                                }
                                            }
                                            alerta.addAction(acaoCancelar)
                                            alerta.addAction(acaoConfirmar)
                                            self.present(alerta, animated: true)
                                            
                                        }//fim longDestino
                                        
                                    }//fim latDestino
                                }
                            }
                        }
                    }else{
                        print("Endereco nao digitado")
                    }
                }
            }
        }
    }
    
    func alternaBotaoEmViagem () {
        self.botaoChamar.setTitle("Em viagem", for: .normal)
        self.botaoChamar.isEnabled = false
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
    }
    
    func alternaBotaoCancelarUber () {
        self.botaoChamar.setTitle("Cancelar Uber", for: .normal)
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.831, green: 0.237, blue: 0.146, alpha: 1)
        self.uberChamado = true
    }
    func alternaBotaoChamarUber () {
        self.botaoChamar.setTitle("Chamar Uber", for: .normal)
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
        self.uberChamado = false
    }
    
    func alternaBotaoViagemFinalizada (preco: Double) {
        self.botaoChamar.isEnabled = false
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
        
        //Formata numero
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "pt_BR")
        let precoFinal = nf.string(from: NSNumber(value: preco))
        
        self.botaoChamar.setTitle("Viagem finalizada - R$ " + precoFinal!, for: .normal)
    }
}
