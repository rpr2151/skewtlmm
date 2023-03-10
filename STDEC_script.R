library(parallel)
library(RcppArmadillo)
library(Rcpp)

sourceCpp('fastLik.cpp')

dropNull = function(lst) {
  return(lst[!sapply(lst, is.null)])
}

globalAssign = function(Y, X, Z, T_i, ni, covar_params, Ga, be, s2, xi, nu) {
  V <<- Ga - xi %*% t(xi)
  V.inv <<- solve(V)
  Ip <<- lapply(T_i, function(x) covar_params[1]^abs(outer(x,x,'-'))^covar_params[2])
  Psi <<- pmap(list(Z, Ip), function(z, ip) z %*% V %*% t(z) +ip)
  Lambda <<- pmap(list(Y, Z, Ip), function(y,z,ip) z %*% Ga %*% t(z) + ip)
  OLO.inv <<- lapply(Lambda, solve)
  Xb = lapply(X, function(x) x %*% be)
  cent <<- pmap(list(Y,Xb), function(y, xb) y - xb)
  m <<- pmap_dbl(list(cent, OLO.inv), function(ce, ol.i) t(ce) %*% ol.i %*% ce)
  dd <<- map(Z, function(z) z %*% xi)
  tmp = pmap(list(dd, OLO.inv), function(d, o) t(d) %*% o)
  kkk = pmap_dbl(list(tmp, dd), function(t, d) c(1-t %*% d))
  sg2 <<- kkk
  sg <<- sqrt(kkk)
  A <<- pmap_dbl(list(tmp, cent, sg), function(tm, ce, sgi) (tm %*% ce)/sgi)
  Sb.inv <<- pmap_dbl(list(Z,Ip), function(oz,ip) V.inv + t(oz) %*% solve(ip) %*% oz)
  Sb <<- map_dbl(Sb.inv, solve) #solve(Sb.inv)
  Sb.m <<- c(Sb)
  ub <<- map_dbl(Sb, function(sb) c(sb %*% V.inv %*% xi))
  vb <<- pmap_dbl(list(Sb, Z, cent, Ip), function(sb, oz, ce, ip) sb %*% t(oz) %*% solve(ip) %*% ce)
  return(0)
}

calc_expect_1 = function(Y, X, Z, T_i, ni, covar_params, Ga, be, s2, xi, nu) {
  #V <- Ga - xi %*% t(xi)
  #V.inv <- solve(V)
  #Ip <- lapply(T_i, function(x) covar_params[1]^abs(outer(x,x,'-'))^covar_params[2])
  #Psi <- pmap(list(Z, Ip), function(z, ip) z %*% V %*% t(z) +ip)
  #Lambda <- pmap(list(Y, Z, Ip), function(y,z,ip) z %*% Ga %*% t(z) + ip)
  #OLO.inv <- lapply(Lambda, solve)
  #Xb = lapply(X, function(x) x %*% be)
  #cent <- pmap(list(Y,Xb), function(y, xb) y - xb)
  #m <- pmap_dbl(list(cent, OLO.inv), function(ce, ol.i) t(ce) %*% ol.i %*% ce)
  #dd <- map(Z, function(z) z %*% xi)
  #tmp = pmap(list(dd, OLO.inv), function(d, o) t(d) %*% o)
  #kkk = pmap_dbl(list(tmp, dd), function(t, d) c(1-t %*% d))
  #sg2 <- kkk
  #sg <- sqrt(kkk)
  #A <- pmap_dbl(list(tmp, cent, sg), function(tm, ce, sgi) (tm %*% ce)/sgi)
  #Sb.inv <- pmap_dbl(list(Z,Ip), function(oz,ip) V.inv + t(oz) %*% solve(ip) %*% oz)
  #Sb <- map_dbl(Sb.inv, solve) #solve(Sb.inv)
  #Sb.m <- c(Sb)
  #ub <- map_dbl(Sb, function(sb) c(sb %*% V.inv %*% xi))
  #vb <- pmap_dbl(list(Sb, Z, cent, Ip), function(sb, oz, ce, ip) sb %*% t(oz) %*% solve(ip) %*% ce)
  
  s = sqrt(s2)
  tau = pmap_dbl(list(ni, m), ~(nu + .x) / (nu + .y / s2))
  c0 = pmap_dbl(list(A,tau),function(a.i,t.i) a.i * sqrt(t.i) / s)
  c2 = pmap_dbl(list(c0, ni),function(c0.i, ni.i) c0.i * sqrt((nu+ni.i+2)/(nu+ni.i)))
  tmp = pmap_dbl(list(c0, ni), function(c0.i,ni.i) dt(c0.i, df=nu+ni.i) / pt(c0.i, df=nu+ni.i))
  hs80 = pmap_dbl(list(tau, tmp), function(tau.i, tmp.i) sqrt(tau.i) / s * tmp.i)
  hs8 = c0 * tmp
  hs2 = pmap_dbl(list(tau, c2, c0, ni), function(tau.i, c2.i, c0.i, ni.i) tau.i * pt(c2.i, df=nu+ni.i+2) / pt(c0.i, df=nu+ni.i))
  hs3 = sg * A * hs2 + s2 * sg * hs80
  hs4 = sg2 * s2 * (A^2 * hs2 / s2 + 1 + hs8)
  #hs5 = t(t(ub) * hs3) + t(t(vb) * hs2)
  #hs6 = t(t(ub) * hs4) + t(t(vb) * hs3)
  
  #hs7 = hs5 * vb + hs6 * ub + Sb.m * s2
  
  sum.hs2 = sum(hs2)
  sum.hs3 = sum(hs3)
  sum.hs4 = sum(hs4)
  #sum.hs5 = sum(hs5) #rowSums(hs5)
  #sum.hs6 = sum(hs6) #rowSums(hs6)
  #sum.hs7 = sum(hs7) #matrix(rowSums(hs7),q,q) 
  XPsiXL = XPsiZL = ZPsiZL = XPsiYL = ZPsiYL = list()
  XPsiXL[[1]] =  hs2[1] * t(X[[1]]) %*% solve(Psi[[1]]) %*% X[[1]]
  XPsiZL[[1]] =   hs3[1] * t(X[[1]]) %*% solve(Psi[[1]]) %*% Z[[1]]
  ZPsiZL[[1]] =   hs4[1] * t(Z[[1]]) %*% solve(Psi[[1]]) %*% Z[[1]]
  XPsiYL[[1]] =   hs2[1] * t(X[[1]]) %*% solve(Psi[[1]]) %*% Y[[1]]
  ZPsiYL[[1]] =   hs3[1] * t(Z[[1]]) %*% solve(Psi[[1]]) %*% Y[[1]]
  Ups1 = pmap(list(hs2, hs3, hs4, cent, dd), function(h2, h3, h4, ce, d) h2*(ce %*% t(ce))+h4 * (d %*% t(d)) - 2*h3*(d %*% t(ce)))
  
  for (i in 2:length(ni)) {
    XPsiXL[[i]] =   hs2[i] * t(X[[i]]) %*% solve(Psi[[i]]) %*% X[[i]]
    XPsiZL[[i]] =    hs3[i] * t(X[[i]]) %*% solve(Psi[[i]]) %*% Z[[i]]
    ZPsiZL[[i]] =    hs4[i] * t(Z[[i]]) %*% solve(Psi[[i]]) %*% Z[[i]]
    XPsiYL[[i]] =    hs2[i] * t(X[[i]]) %*% solve(Psi[[i]]) %*% Y[[i]]
    ZPsiYL[[i]]  =   hs3[i] * t(Z[[i]]) %*% solve(Psi[[i]]) %*% Y[[i]]
    
  }
  XPsiX = Reduce( '+',XPsiXL)
  XPsiZ = Reduce( '+',XPsiZL)
  ZPsiZ = Reduce( '+',ZPsiZL)
  XPsiY = Reduce( '+',XPsiYL)
  ZPsiY = Reduce( '+',ZPsiYL)
  
  #hs2 = hs2, hs3 = hs3, hs4 = hs4, hs5 = hs5, hs6 = hs6, hs7 = hs7, sum.hs2 = sum.hs2, sum.hs3 = sum.hs3, sum.hs4= sum.hs4, sum.hs5= sum.hs5, sum.hs6= sum.hs6, sum.hs7= sum.hs7
  return(list(hs4= hs4,XPsiX = XPsiX,XPsiY = XPsiY, XPsiZ = XPsiZ, ZPsiZ = ZPsiZ, ZPsiY = ZPsiY, Ups1 = Ups1))
  
}

calc_expect_2 = function(Y, X, Z, T_i, nu, ni,s2, be, Ga, xi) {
  
  s = sqrt(s2)
  
  #V = Ga - xi %*% t(xi)
  #V.inv = solve(V)
  
  #Ip = lapply(T_i, function(x) covar_params[1]^abs(outer(x,x,'-'))^covar_params[2])
  #Xb = lapply(X, function(x) x %*% be)
  #cent = pmap(list(Y,Xb), function(y, xb) y - xb)
  
  #Lambda = pmap(list(Y, Z, Ip), function(y,z,ip) z %*% Ga %*% t(z) + ip)
  #OLO.inv = lapply(Lambda, solve)
  #dd <<- map(Z, function(z) z %*% xi)
  
  #tmp = pmap(list(dd, OLO.inv), function(d, o) t(d) %*% o)
  #kkk = pmap_dbl(list(tmp, dd), function(t, d) c(1-t %*% d))
  #sg2 <<- kkk
  #sg <<- sqrt(kkk)
  #A <<- pmap_dbl(list(tmp, cent, sg), function(tm, ce, sgi) (tm %*% ce)/sgi)
  
  tau = pmap_dbl(list(ni, m), ~(nu + .x) / (nu + .y / s2))
  c0 = pmap_dbl(list(A,tau),function(a.i,t.i) a.i * sqrt(t.i) / s)
  c2 = pmap_dbl(list(c0, ni),function(c0.i, ni.i) c0.i * sqrt((nu+ni.i+2)/(nu+ni.i)))
  tmp = pmap_dbl(list(c0, ni), function(c0.i,ni.i) dt(c0.i, df=nu+ni.i) / pt(c0.i, df=nu+ni.i))
  hs80 = pmap_dbl(list(tau, tmp), function(tau.i, tmp.i) sqrt(tau.i) / s * tmp.i)
  
  hs8 = c0 * tmp
  # hs2 = tau * pt(c2, df=nu+ni+2) / pt(c0, df=nu+ni)
  hs2 = pmap_dbl(list(tau, c2, c0, ni), function(tau.i, c2.i, c0.i, ni.i) tau.i * pt(c2.i, df=nu+ni.i+2) / pt(c0.i, df=nu+ni.i))
  hs3 = pmap_dbl(list(sg, A, hs2, hs80), function(sg.i, A.i, hs2.i, hs80.i) sg.i*A.i*hs2.i + s2*sg.i*hs80.i)#sg * A * hs2 + s2 * sg * hs80
  hs4 = pmap_dbl(list(sg2, A, hs2, hs8), function(sg2.i, A.i, hs2.i, hs8.i) sg2.i *s2* (A.i^2 * hs2.i / s2 + 1+ hs8.i)) #sg2 * s2 * (A^2 * hs2 / s2 + 1 + hs8)
  hs5 = t(t(ub) * hs3) + t(t(vb) * hs2)
  hs6 = t(t(ub) * hs4) + t(t(vb) * hs3)
  
  hs7 = pmap_dbl(list(hs5, vb, hs6, ub, Sb.m), function(hs5.i, vb.i, hs6.i, ub.i, Sb.m.i) hs5.i * vb.i + hs6.i * ub.i + Sb.m.i * s2)#hs5 * vb + hs6 * ub + Sb.m * s2
  
  #hs2 = hs2, hs3 = hs3, hs4 = hs4, hs5 = hs5, hs6 = hs6, hs7 = hs7, sum.hs2 = sum.hs2, sum.hs3 = sum.hs3, sum.hs4= sum.hs4, sum.hs5= sum.hs5, sum.hs6= sum.hs6, sum.hs7= sum.hs7
  return(list(hs4 = hs4, hs6 = hs6, hs7 = hs7))
}

clusterExport(cl, c('calc_expect_1', 'calc_expect_2', 'globalAssign'))

sqrt.mt = function(S)
{
  p = ncol(S)
  if(p == 1) S.sqrt = as.matrix(sqrt(S))
  else
  {
    eig.S = eigen(S)
    S.sqrt = eig.S$ve %*% diag(sqrt(eig.S$va),p) %*% t(eig.S$ve)
  }
}

CML.nu.fn = function(nu, m, A, detL, s2)
{
  mvt.den = lgamma(.5*(nu+ni))-lgamma(.5*nu)-.5*log(detL)-.5*ni*log(pi*nu*s2)-.5*(nu+ni)*log(1+m/s2/nu)
  Tcdf = log(pt(A*sqrt((nu+ni)/(s2*nu+m)),df=nu+ni))
  val = sum(log(2)+mvt.den+Tcdf)
  return( - val)
}


#initial values
logli.vector = c()
param.vector = list()
diff_vec = c()
t1 = Sys.time()
tol = 1e-4
be = c(1,0,0); covar_params = c(.5,0.9); la = c(3); s2 = 2; Ga = matrix(c(0.35),1,1); nu = 7

#initial setup

p = ncol(X[[1]]); q = ncol(Z[[1]])
tgen = lapply(T_i, function(x) abs(outer(x,x,'-')))
Ip = lapply(T_i, function(x) covar_params[1]^abs(outer(x,x,'-'))^covar_params[2]) #lapply(T_i, function(t) construct_cov(covar_params, t)) #lapply(ni, function(x) diag(x))

n = sum(ni)

Xb = lapply(X, function(x) x %*% be)
cent = pmap(list(Y,Xb), function(y, xb) y - xb)
Lambda = pmap(list(Y, Z, Ip), function(y,z,ip) z %*% Ga %*% t(z) + ip)
FF = sqrt.mt(Ga)
delta = la / sqrt(1 + sum(la^2))
xi = matrix(c(FF %*% delta),nrow = ncol(Z[[1]])) #as.matrix(c(FF %*% delta))
dd = map(Z, function(z) z %*% xi) #c(Z.uni %*% xi)
m = A = detL = sg2 = sg = rep(NA,N)

V = Ga - xi %*% t(xi)
V.inv = solve(V)
s = sqrt(s2)

OLO = Lambda #O %*% Lambda %*% t(O)
OLO.inv = lapply(OLO, solve) #solve(OLO)
Odd = dd #c(O %*% dd)
tmp = pmap(list(dd, OLO.inv), function(d, o) t(d) %*% o)#t(Odd)%*% OLO.inv
ind.cent = cent #O %*% matrix(cent, maxni)
kkk = pmap_dbl(list(tmp, dd), function(t, d) c(1-t %*% d))#c(1-tmp %*% Odd)
sg2 = kkk
sg = sqrt(kkk) #lapply(kkk, sqrt) #sqrt(kkk)
A = pmap_dbl(list(tmp, cent, sg), function(tm, ce, sgi) (tm %*% ce)/sgi)#(tmp %*% ind.cent)/sqrt(kkk)
m = pmap_dbl(list(cent, OLO.inv), function(ce, ol.i) t(ce) %*% ol.i %*% ce) #t(cent) %*% OLO %*% cent #colSums((OLO.inv %*% ind.cent) * ind.cent)
detL = sapply(OLO, det)#det(OLO)
#OZ = Z.uni #O %*% Z.uni
OZ = Z
Sb.inv = pmap_dbl(list(OZ,Ip), function(oz,ip) V.inv + t(oz) %*% solve(ip) %*% oz)   #MAYBE NOT _DBL CHECK THIS 
Sb = map_dbl(Sb.inv, solve) #solve(Sb.inv)
Sb.m = c(Sb)
ub = map_dbl(Sb, function(sb) c(sb %*% V.inv %*% xi))#c(Sb %*% V.inv %*% xi)
vb = pmap_dbl(list(Sb, OZ, cent, Ip), function(sb, oz, ce, ip) sb %*% t(oz) %*% solve(ip) %*% ce)#Sb %*% t(OZ) %*% ind.cent
#}
mvt.den = lgamma(.5*(nu+ni))-lgamma(.5*nu)-.5*log(detL)-.5*ni*log(pi*nu*s2)-.5*(nu+ni)*log(1+m/s2/nu)
Tcdf = log(pt(A*sqrt((nu+ni)/(s2*nu+m)),df=nu+ni))
logli.old = sum(log(2)+mvt.den+Tcdf)
iter = 0
iter_adv= 0


repeat
{
  iter = iter + 1
  iter_adv = iter_adv + 1
  if (nwait/numCores<=.25) {
  refresh = 3
  restart = 9
  } else {
    refresh = 4
    restart = 10
  }
  if (iter == 1 | (iter %% restart == 0) ) {
    E1 = list()
    clusterExport(cl, c('covar_params', 'be', 's2','Ga', 'xi', 'nu'))
    for (i in 1:length(cl)) {
      clusterEvalQ(cl[i],  globalAssign(Y, X, Z, T_i, ni, covar_params,Ga, be, s2, xi, nu))
    }
    estep_upd = clusterEvalQ(cl,  calc_expect_1(Y, X, Z, T_i, ni, covar_params,Ga, be, s2, xi, nu))
    
    E1$hs4 = do.call(c, map(estep_upd, 'hs4'))
    E1$XPsiZ = map(estep_upd, 'XPsiZ')
    E1$XPsiY = map(estep_upd, 'XPsiY')
    E1$XPsiX = map(estep_upd, 'XPsiX')
    E1$ZPsiZ = map(estep_upd, 'ZPsiZ')
    E1$ZPsiY = map(estep_upd, 'ZPsiY')
    E1$Ups1 = map(estep_upd, 'Ups1')
    
    
    
    XPsiZ = Reduce('+',E1$XPsiZ)
    XPsiX = Reduce('+',E1$XPsiX)
    XPsiY = Reduce('+',E1$XPsiY)
    ZPsiZ = Reduce('+',E1$ZPsiZ)
    ZPsiY = Reduce('+',E1$ZPsiY)
    Ups1 = Reduce(c,E1$Ups1)
    
    #if((iter %% restart == 0)) {
    #  iter_adv = iter_adv + 1
    #}
    
  } else {
    
    
    clusterExport(cl, c('covar_params', 'be', 's2','Ga', 'xi', 'nu'))
    
    
    retSamp = (1:nwait + nwait*iter_adv) %% numCores #sort(sample(1:numCores, nwait))
    retSamp[retSamp == 0] = numCores
    retSamp = sort(retSamp)
    retIdx1 = rep(FALSE, numCores)
    retIdx1[retSamp] <- TRUE
    
    for (i in retSamp) {
      clusterEvalQ(cl[i],  globalAssign(Y, X, Z, T_i, ni, covar_params,Ga, be, s2, xi, nu))
    }
    
    estep_upd = clusterEvalQ(cl[retSamp],  calc_expect_1(Y, X, Z, T_i, ni, covar_params,Ga, be, s2, xi, nu))
    #retIdx1 <- !(sapply(estep_upd, is.null))
    
    mod_inds = do.call(c,idList[which(retIdx1)])
    E1$hs4[mod_inds] = do.call(c, map(estep_upd, 'hs4'))
    E1$XPsiZ[which(retIdx1)] = map(estep_upd, 'XPsiZ') %>% dropNull
    E1$XPsiY[which(retIdx1)] = map(estep_upd, 'XPsiY') %>% dropNull
    E1$XPsiX[which(retIdx1)] = map(estep_upd, 'XPsiX') %>% dropNull
    E1$ZPsiZ[which(retIdx1)] = map(estep_upd, 'ZPsiZ') %>% dropNull
    E1$ZPsiY[which(retIdx1)] = map(estep_upd, 'ZPsiY') %>% dropNull
    E1$Ups1[which(retIdx1)] = map(estep_upd, 'Ups1') %>% dropNull
    
    
    
    XPsiZ = Reduce('+',E1$XPsiZ)
    XPsiX = Reduce('+',E1$XPsiX)
    XPsiY = Reduce('+',E1$XPsiY)
    ZPsiZ = Reduce('+',E1$ZPsiZ)
    ZPsiY = Reduce('+',E1$ZPsiY)
    Ups1 = Reduce(c,E1$Ups1)
    
    
    
  }
  
  # M-step
  
  
  
  bx.part1 = rbind(cbind(XPsiX, XPsiZ), cbind(t(XPsiZ),ZPsiZ))
  bx.part2 = c(XPsiY, ZPsiY)
  bx = c(solve(bx.part1) %*% bx.part2)
  be = bx[1:p]; xi = bx[p+1:q]
  
  
  Xb = lapply(X, function(x) x %*% be)
  cent = pmap(list(Y,Xb), function(y, xb) y - xb)
  dd = map(Z, function(z) z %*% xi)
  
  Psi = pmap(list(Z, Ip), function(z, ip) z %*% V %*% t(z) +ip) 
  
  s2 = tryCatch(sum(pmap_dbl(list(Psi, Ups1,E1$hs4), function(ps, up,h4) sum(diag(solve(ps) %*% up)) + h4)) / (sum(ni) + N), error = function(e) browser()) #c(trPsiUps1) + sum.hs4) / (n + N)
  
  if (iter == 1 | (iter %% restart == 0) ) {
    E2 = list()
    clusterExport(cl, c( 'be', 's2','Ga', 'xi', 'nu'))
    estep_upd = clusterEvalQ(cl, calc_expect_2(Y, X, Z, T_i, nu, ni,s2, be, Ga, xi))
    
    E2$hs4 = do.call(c, map(estep_upd, 'hs4'))
    E2$hs6 = do.call(c, map(estep_upd, 'hs6'))
    E2$hs7 = do.call(c, map(estep_upd, 'hs7'))
  } else {
    clusterExport(cl, c( 'be', 's2','Ga', 'xi', 'nu'))
    retSamp = (1:nwait + nwait*iter_adv) %% numCores #sort(sample(1:numCores, nwait))
    retSamp[retSamp == 0] = numCores
    retSamp = sort(retSamp)
    retIdx1 = rep(FALSE, numCores)
    retIdx1[retSamp] <- TRUE
    
    estep_upd = clusterEvalQ(cl[retSamp], calc_expect_2(Y, X, Z, T_i, nu, ni,s2, be, Ga, xi))
    #retIdx1 <- !(sapply(estep_upd, is.null))
    
    mod_inds = do.call(c,idList[which(retIdx1)])
    E2$hs4[mod_inds] = do.call(c, map(estep_upd, 'hs4')%>% dropNull)
    E2$hs6[mod_inds] = do.call(c, map(estep_upd, 'hs6')%>% dropNull)
    E2$hs7[mod_inds] = do.call(c, map(estep_upd, 'hs7')%>% dropNull)
    
  }
  
  
  sum.Ups3 = with(E2, sum(E2$hs7) + sum(E2$hs4) * xi %*% t(xi) - sum(E2$hs6) %*% t(xi) - xi %*% t(sum(hs6)))
  
  V = sum.Ups3 / (N * s2)
  
  Ga = V + xi %*% t(xi)
  FF = sqrt.mt(Ga)
  la = c(solve(FF) %*% xi) / c(sqrt(1 - t(xi) %*% solve(Ga) %*% xi))
  delta = la / sqrt(1 + sum(la^2))
  
  V.inv = solve(V)
  s = sqrt(s2)
  
  detL = do.call(c, clusterEvalQ(cl,  sapply(Lambda, det)))
  m = do.call(c,clusterEvalQ(cl, m))
  A = do.call(c,clusterEvalQ(cl, A))
  nu.optim = optim(par = nu, fn = CML.nu.fn, method = "L-BFGS-B", lower = 3, upper = 10, m=m, A=A, detL=detL, s2=s2, control = list(factr = 1e16))
  nu = nu.optim$par
  
  
  if ((iter %% refresh) == 0 | iter == 1) {
    rho.optim = optim(par = covar_params, fn = fastLikelihood, method = 'L-BFGS-B', lower = c(0.01, 0.2), upper = c(0.99,2), nu = nu,ni = ni, Ga = Ga, Z =Z, cent = cent, delta = delta, s2 = s2, T_i = tgen, dd = dd, N = length(ni), control = list(factr = 1e16))
    covar_params = rho.optim$par
    logli.new = -rho.optim$value
  } else {
    logli.new = -fastLikelihood(covar_params, nu = nu,ni = ni, Ga = Ga, Z =Z, cent = cent, delta = delta, s2 = s2, T_i = tgen, dd = dd, N = length(ni))
  }
  
  
  diff = logli.new - logli.old
  diff_vec <<- c(diff_vec, diff)
  #if ((iter %% 5) == 0) {
  cat('iter =', iter, '\tlogli =', logli.new, '\tdiff =', diff, '\n')
  #}
  if( diff > 0 & diff < tol & (iter %% restart != 1)) break
  logli.old = logli.new
  logli.vector = c(logli.vector, logli.new)
  param.vector[[iter]] = c(be, delta, xi, s2, Ga, FF, nu, covar_params)
}
t2 = Sys.time()
num.para = p+q+1+q*(q+1)/2+1
aic = -2 * logli.new + 2      * num.para
bic = -2 * logli.new + log(N) * num.para

model.inf = c(num.para, logli.new, aic, bic)
names(model.inf) = c('num.para', 'logli', 'AIC', 'BIC')

para = list(model.inf = model.inf, beta = be, lambda = cbind(la,delta,xi), s2 = c(s=s,s2=s2), Gamma = Ga, F = FF, nu = nu, covar_params = covar_params,time = c(t2-t1, iter, logli.new, logli.vector), param.vector = param.vector)
#print(para)
print(t2-t1)