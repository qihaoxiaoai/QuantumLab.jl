using QuantumLab
using Base.Test

# write your own tests here
@test 1 == 1

# test readGeometryXYZ
h2o = readGeometryXYZ("h2o.xyz")
@test h2o.atoms[2].element.symbol == "O"
@test_approx_eq_eps -1.4191843 readGeometryXYZ("h2o.xyz").atoms[3].position.x 1e-7

# test AtomModule
@test Element("C") == Element("C")
el1 = Element("C")
el2 = Element("C")
@test isequal(el1,el2)
@test !isequal(el1,Element("Na"))

# test BaseModule
mqn = MQuantumNumber(0,0,0)
for (mqn in MQuantumNumbers(LQuantumNumber("D"))) end
@test mqn == MQuantumNumber(0,0,2)
@test distance(Position(0,0,1),Position(1,0,0)) == sqrt(2)
@test length(MQuantumNumbers(LQuantumNumber("P"))) == 3
@test 2*Position(1,2,3) == Position(1,2,3)*2
@test isless(LQuantumNumber("S"),LQuantumNumber("P"))
@test_approx_eq 0. BaseModule.evaluateFunction(Position(1.,2.,3.), x->x.x+x.y-x.z)

# test BasisSetExchange
# as this takes quite some time we primarily only want to do this during continuous integration (travis-ci) and when we haven-t checked this before
if (!isfile("STO-3G.tx93"))
  bseEntries = obtainBasisSetExchangeEntries()
  display(bseEntries)
  stoEntry   = computeBasisSetExchangeEntry("sto-3g",bseEntries)[3]
  downloadBasisSetBasisSetExchange(stoEntry,"STO-3G.tx93")
  @test_throws ErrorException computeBasisSetExchangeEntry("NotDefined",bseEntries)
end

# test readBasisSetTX93
sto3g = readBasisSetTX93("STO-3G.tx93")
@test sto3g.definitions[Element("C")][1].lQuantumNumber.symbol == "S"
@test sto3g.definitions[Element("C")][1].primitives[1].exponent == 71.616837

# test BasisModule
bas = computeBasis(sto3g,h2o)
@test_approx_eq_eps -0.7332137 bas.contractedBFs[3].primitiveBFs[1].center.y 1e-7
@test_approx_eq_eps 0.35175381 BasisFunctionsModule.evaluateFunction(origin, bas.contractedBFs[3]) 1e-8

# test IntegralsModule
normalize!(bas)
matrixOverlap = computeMatrixOverlap(bas)
matrixKinetic = computeMatrixKinetic(bas)
@test_approx_eq 0.0 matrixOverlap[6,1]
@test_approx_eq_eps 0.3129324434238492 matrixOverlap[4,1] 1e-8
@test_approx_eq_eps 29.00 matrixKinetic[2,2] 1e-2
@test_approx_eq_eps 0.16175843 IntegralsModule.FIntegral(2,0.3) 1e-8
@test_approx_eq -π IntegralsModule.NuclearAttractionIntegral(PrimitiveGaussianBasisFunction(Position(0,0,0),1.,MQuantumNumber(1,0,0)),PrimitiveGaussianBasisFunction(Position(0,0,0),1.,MQuantumNumber(1,0,0)),Atom(Element("C"),Position(0,0,0)))
@test_approx_eq IntegralsModule.GaussianIntegral1D_Mathematica(6,1.2)  IntegralsModule.GaussianIntegral1D_Valeev(6,1.2)
@test_approx_eq IntegralsModule.OverlapFundamental(bas.contractedBFs[1].primitiveBFs[1],bas.contractedBFs[1].primitiveBFs[2]) computeValueOverlap(bas.contractedBFs[1].primitiveBFs[1],bas.contractedBFs[1].primitiveBFs[2])

# test InitialGuessModule
matrixSADguess = computeDensityGuessSAD("HF","STO-3G",h2o)
@test_approx_eq_eps -0.264689 mean(matrixSADguess)[3,2] 1e-6
@test_throws ErrorException computeDensityGuessSAD("NotImplemented","STO-3G",h2o)

# test SpecialMatricesModule
@test_approx_eq_eps -0.785008186026 mean(computeMatrixFock(bas,h2o,matrixSADguess[1])) 1e-10                  #### !!!! ####

# test HartreeFockModule
density = evaluateSCF(bas,h2o,mean(matrixSADguess),5)[3]
@test_approx_eq -4.473355520007 mean(HartreeFockModule.evaluateSCFStep(bas,h2o,mean(matrixSADguess),matrixOverlap,5)[1])
@test_approx_eq_eps -74.96178985 (computeEnergyHartreeFock(bas,h2o,density) + computeEnergyInteratomicRepulsion(h2o)) 1e-7 # checked against FermiONs++

# test Shells: ShellModule and LibInt2Module
shell_native  = Shell(LQuantumNumber("S"),Position(0.,0.,0.),[1.,2.,3.],[.1,.2,.3])
shell_libint2 = LibInt2Shell([0.,0.,0.],0,3,[1.,2.,3.],[.1,.2,.3])
shell_nativefromlibint2 = Shell(shell_libint2)
@test_approx_eq shell_native.coefficients[2] .2
@test_approx_eq_eps shell_nativefromlibint2.coefficients[2] 0.41030724 1e-8

# test LibInt2Module
libInt2Finalize()
libInt2Initialize()
tmp_lib = LibInt2Shell([0.,1.,2.],1,2,[1.,2.],[0.5,0.5];renorm=false)
tmp = Shell(tmp_lib).coefficients
@test_approx_eq tmp[1] tmp[2]
destroy!(tmp_lib)
shells = computeBasisShellsLibInt2(sto3g,h2o)
S = computeMatrixOverlap(shells)
@test_approx_eq S computeMatrixOverlap(bas)
T = computeMatrixKinetic(shells)
@test_approx_eq T computeMatrixKinetic(bas)
J = computeMatrixCoulomb(shells,density)
@test_approx_eq_eps J computeMatrixCoulomb(bas,density) 1e-8
@test_approx_eq computeMatrixBlockOverlap(shells[1],shells[1]) S[1,1]
@test_approx_eq computeMatrixBlockKinetic(shells[1],shells[1]) T[1,1]
@test_approx_eq computeElectronRepulsionIntegral(shells[1],shells[5],shells[4],shells[4])[1,1,2,2] computeElectronRepulsionIntegral(bas.contractedBFs[1],bas.contractedBFs[7],bas.contractedBFs[5],bas.contractedBFs[5])

# test LaplaceModule
if(!isdir("hackbusch_pretables"))
  downloadLaplacePointsHackbusch("hackbusch_pretables")
end
R = transformRangeToIdealLaplace(0.5,3.)[2]
lp = transformLaplacePointFromIdealLaplace( findLaplacePointsHackbuschPretableLarger(15,R,"hackbusch_pretables")[1], 0.5)
@test_throws ErrorException findLaplacePointsHackbuschPretableSmaller(15,R,"hackbusch_pretables")
@test_approx_eq_eps LaplaceModule.computeInverseByLaplaceApproximation(2.3,lp) 1./2.3 1e-7
@test_approx_eq_eps LaplaceModule.computeRPADenominatorByDoubleLaplace(1.2,2.3,lp) 1./(1.2^2 + 2.3^2) 1e-3
@test findLaplacePointsHackbuschPretableLarger(2,100.,"hackbusch_pretables") == findLaplacePointsHackbuschPretableLarger(2,50.,"hackbusch_pretables")
@test transformLaplacePointFromIdealLaplace( findLaplacePointsHackbuschPretableSmaller(15,transformRangeToIdealLaplace(0.5,6.)[2],"hackbusch_pretables")[1], 0.5) == lp

# test RI-Module
@test_approx_eq 0.3950752513027109 mean(computeMatrixExchangeRIK(bas,bas,matrixSADguess[1]))
tensorRICoulomb = computeTensorElectronRepulsionIntegralsRICoulomb(bas,bas)
@test_approx_eq 0.0429373705056905 mean(tensorRICoulomb)
@test_approx_eq 0.0012436634924295 tensorRICoulomb[1,3,4,5]
tensorRIOverlap = computeTensorElectronRepulsionIntegralsRIOverlap(bas,bas)
@test_approx_eq 0.0144597945326691 tensorRIOverlap[1,3,4,5]
@test_approx_eq 0.0537036598506078 mean(tensorRIOverlap)






### display functions ###
# These are simply here, so that the test coverage isn't limited by the display functions.
# They do not however test for anything really, so do not trust them. If you do add a *real* 
# test for a display function, please add it to the corresponding module block above instead
# of here.
display(bas)
display(bas.contractedBFs[3])
display(JournalCitation(["M. Mustermann"],"J. Stup. Mistakes",1,12,2016))
display(GenericCitation("M. Mustermann personal note"))
display(BookCitation(["C. Darwin"], "On the Origin of Species", "978-0451529060"))
display([BookCitation(["C. Darwin"], "On the Origin of Species", "978-0451529060"), JournalCitation(["M. Mustermann"],"J. Stup. Mistakes",1,12,2016)])
display([Base.Markdown.parse("**Why, god, why??**"),BookCitation(["C. Darwin"], "On the Origin of Species", "978-0451529060"), JournalCitation(["M. Mustermann"],"J. Stup. Mistakes",1,12,2016)])
display([JournalCitation(["M. Mustermann"],"J. Stup. Mistakes",1,12,2016),JournalCitation(["M. Mustermann"],"J. Stup. Mistakes",1,12,2016)])
display(@doc(IntegralsModule.GaussianIntegral1D_Valeev))
display(shells[1])
display(lp)
summarize(BasisModule.Basis)
summarize(GaussianBasis)
