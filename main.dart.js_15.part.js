((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,K,I,M,A={Fk:function Fk(d,e,f,g,h,i,j){var _=this
_.B=null
_.n=d
_.ag=e
_.bL=f
_.a4=_.bC=null
_.dH=g
_.n$=h
_.dy=i
_.b=_.fy=null
_.c=0
_.y=_.d=null
_.z=!0
_.Q=null
_.as=!1
_.at=null
_.ay=$
_.ch=j
_.CW=!1
_.cx=$
_.cy=!0
_.db=!1
_.dx=$},akP:function akP(d){this.a=d},Py:function Py(d,e,f,g){var _=this
_.e=d
_.f=e
_.c=f
_.a=g},
b5K(d){var x,w,v,u=y.g.a(d.i(0,"profiles"))
if(u==null)u=C.U
x=J.d8(u,y.f)
x=B.cB(x,new A.aq5(),x.$ti.h("p.E"),y.U)
w=B.x(x,B.l(x).h("p.E"))
x=d.i(0,"dataset")
if(x!=null)J.T(x)
x=d.i(0,"generated_at_utc")
if(x!=null)J.T(x)
x=d.i(0,"source_mode")
if(x!=null)J.T(x)
x=d.i(0,"latest_snapshot_date")
x=x==null?null:J.T(x)
v=d.i(0,"previous_snapshot_date")
v=v==null?null:J.T(v)
A.a3R(d.i(0,"profile_count"),w.length)
return new A.mi(x,v,w)},
b5J(d){var x,w,v,u,t,s,r,q,p,o,n,m=y.g.a(d.i(0,"source_history"))
if(m==null)m=C.U
x=d.i(0,"slug")
x=x==null?null:J.T(x)
if(x==null)x=""
w=d.i(0,"display_name")
w=w==null?null:J.T(w)
if(w==null)w=""
v=A.vF(d.i(0,"trend_score_actual"))
A.a41(d.i(0,"trend_score_prev"))
u=A.a41(d.i(0,"delta_score"))
t=A.a3R(d.i(0,"ranking_actual"),0)
A.a42(d.i(0,"ranking_prev"))
s=A.a42(d.i(0,"delta_ranking"))
A.aNb(d.i(0,"sources_present"))
r=y.Y
q=A.aM3(r.a(d.i(0,"github_summary")),"GitHub","github")
p=A.aM3(r.a(d.i(0,"stackoverflow_summary")),"StackOverflow","stackoverflow")
o=A.aM3(r.a(d.i(0,"reddit_summary")),"Reddit","reddit")
n=J.d8(m,y.f)
n=B.cB(n,new A.aq4(),n.$ti.h("p.E"),y.H)
n=B.x(n,B.l(n).h("p.E"))
r=r.a(d.i(0,"summary_insights"))
return new A.yK(x,w,v,u,t,s,q,p,o,n,A.b5L(r==null?null:r.bh(0,y.N,y.z)))},
aM3(d,e,f){var x
if(d==null)return new A.U6(e,!1,0,null,null)
x=d.i(0,"source")
if(x!=null)J.T(x)
x=d.i(0,"display_name")
x=x==null?null:J.T(x)
if(x==null)x=e
return new A.U6(x,J.d(d.i(0,"available"),!0),A.vF(d.i(0,"score_actual")),A.a41(d.i(0,"score_prev")),A.a41(d.i(0,"delta_score")))},
b5L(d){var x,w,v,u,t=null
if(d==null)return new A.U7(t,D.CK,D.CL)
x=y.Y
w=x.a(d.i(0,"dominant_source"))
v=w==null?t:w.bh(0,y.N,y.z)
if(v==null)w=t
else{w=v.i(0,"source")
if(w!=null)J.T(w)
w=v.i(0,"display_name")
if(w!=null)J.T(w)
A.vF(v.i(0,"score"))
w=v.i(0,"label")
w=w==null?t:J.T(w)
w=new A.aq3(w==null?"":w)}u=x.a(d.i(0,"coverage"))
u=A.b5H(u==null?t:u.bh(0,y.N,y.z))
x=x.a(d.i(0,"momentum"))
return new A.U7(w,u,A.b5I(x==null?t:x.bh(0,y.N,y.z)))},
b5H(d){var x
if(d==null)return D.CK
A.a3R(d.i(0,"source_count"),0)
A.aNb(d.i(0,"sources_present"))
x=d.i(0,"label")
x=x==null?null:J.T(x)
return new A.U4(x==null?"":x)},
b5I(d){var x
if(d==null)return D.CL
A.a3R(d.i(0,"ranking_actual"),0)
A.a42(d.i(0,"ranking_prev"))
A.a42(d.i(0,"delta_ranking"))
A.vF(d.i(0,"score_actual"))
A.a41(d.i(0,"score_prev"))
x=d.i(0,"label")
x=x==null?null:J.T(x)
return new A.U5(x==null?"":x)},
a3R(d,e){var x
if(B.fc(d))return d
x=d==null?null:J.T(d)
x=B.bV(x==null?"":x,null)
return x==null?e:x},
vF(d){var x
if(typeof d=="number")return d
if(B.fc(d))return d
x=d==null?null:J.T(d)
x=B.e4(x==null?"":x)
return x==null?0:x},
a41(d){var x=d==null?null:J.T(d)
return B.e4(x==null?"":x)},
a42(d){var x=d==null?null:J.T(d)
return B.bV(x==null?"":x,null)},
aNb(d){var x
if(y.j.b(d)){x=J.dF(d,new A.aI2(),y.N)
x=B.x(x,x.$ti.h("X.E"))
return x}return C.c4},
mi:function mi(d,e,f){this.d=d
this.e=e
this.r=f},
aq5:function aq5(){},
yK:function yK(d,e,f,g,h,i,j,k,l,m,n){var _=this
_.a=d
_.b=e
_.c=f
_.e=g
_.f=h
_.w=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n},
aq4:function aq4(){},
U6:function U6(d,e,f,g,h){var _=this
_.b=d
_.c=e
_.d=f
_.e=g
_.f=h},
k2:function k2(d,e,f,g){var _=this
_.a=d
_.c=e
_.d=f
_.e=g},
U7:function U7(d,e,f){this.a=d
this.b=e
this.c=f},
aq3:function aq3(d){this.d=d},
U4:function U4(d){this.c=d},
U5:function U5(d){this.f=d},
aI2:function aI2(){},
aJy:function aJy(){},
aJx:function aJx(){},
qt:function qt(d){this.a=d},
b6t(d){return new A.v6(d,null)},
aMf(d,e){return new B.d4(d,B.F(d).h("d4<1>")).gdF().e6(0,new A.ars(e),y.D).bY(0)},
b6C(d,e){var x,w,v,u,t
if(d==null||e.length===0)return null
for(x=d.r,w=x.length,v=0;u=x.length,v<u;x.length===w||(0,B.z)(x),++v){t=x[v]
if(B.AG(t.a)===e)return t}for(v=0;v<x.length;x.length===u||(0,B.z)(x),++v){t=x[v]
if(B.AG(t.b)===e)return t}return null},
aSW(d){var x=B.jE(d==null?"":d)
if(x==null)return""
return C.b.eG(C.e.k(B.q5(x)),2,"0")+"/"+C.b.eG(C.e.k(B.kN(x)),2,"0")+"/"+B.hC(x)},
b6u(d,e){if(d.length===0||e.length===0)return""
return"Comparado (UTC): "+d+" -> "+e},
b6y(d){var x=B.jE(d)
if(x==null)return d
return C.b.eG(C.e.k(B.q5(x)),2,"0")+"/"+C.b.eG(C.e.k(B.kN(x)),2,"0")},
Hh(d){if(d==null)return"-"
return C.d.K(d,2)},
arS(d){var x
if(d==null)return"-"
x=d>0?"+":""
return x+C.d.K(d,2)},
arj(d,e){var x
if(d==null)return"Sin hist\xf3rico previo"
x=e.length!==0?" "+e:""
return A.arS(d)+x+" vs corrida previa"},
b6x(d){if(d==null)return"Sin hist\xf3rico previo"
if(d===0)return"Tendencia estable"
if(d>0)return"Sube "+Math.abs(d)+" posiciones"
return"Baja "+Math.abs(d)+" posiciones"},
b6w(d){if(d==null)return C.aj
if(d>0)return D.l5
if(d<0)return C.bo
return C.d1},
b6B(d){if(d==null)return C.aj
if(d>0)return D.l5
if(d<0)return C.bo
return C.d1},
aSX(d){var x,w
if(!C.b.l(d,"\xc3")&&!C.b.l(d,"\xc2"))return d
try{x=C.a_.hm(C.MG.c8(d))
return x}catch(w){return d}},
aMi(d){var x,w,v=C.b.au(A.aSX(d))
if(v.length===0)return v
x=C.b.hs(v,B.bd("[.!?]",!0,!1,!1))
w=x>0&&x<120?C.b.a6(v,0,x+1):v
return w.length>120?C.b.wI(C.b.a6(w,0,117))+"...":w},
b6z(d){var x,w=C.b.au(A.aSX(d))
if(w.length===0)return w
x=w.toLowerCase()
if(C.b.l(x,"gana 0")||C.b.l(x,"gana 0.0")||C.b.l(x,"mantiene"))return"Mantiene su posici\xf3n frente a la corrida previa."
return w},
aMj(d,e){var x
if(!d.c)return"Fuente no disponible en esta corrida."
x=d.f
if(x==null||e.length===0)return"Sin hist\xf3rico previo para comparar."
if(x===0)return"Se mantiene estable vs la corrida anterior."
if(x>0)return"Aporta crecimiento frente a la corrida anterior."
return"Pierde tracci\xf3n frente a la corrida anterior."},
aMh(d){return new B.d4(d,B.F(d).h("d4<1>")).gdF().e6(0,new A.arz(),y.D).bY(0)},
aSV(d){var x,w,v=C.b.au(d),u=v.length
if(u===0)return"Tecnolog\xeda"
x=B.AG(v)
if(x==="ai-ml")return"AI/ML"
if(x==="c-sharp")return"C#"
if(x==="c-plus-plus")return"C++"
w=v.toLowerCase()
if(w==="javascript")return"JavaScript"
if(w==="typescript")return"TypeScript"
if(C.b.l(v,"-"))return new B.dP(new B.a3(B.b(v.split("-"),y.s),new A.arQ(),y.A),new A.arR(),y.X).b2(0," ")
if(u===1)return v.toUpperCase()
return v[0].toUpperCase()+C.b.bl(v,1)},
b6v(b1,b2,b3,b4,b5){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3=null,a4=A.a4g(b4),a5=b1==null?a3:b1.b,a6=b3==null?a3:b3.b,a7=b2==null,a8=a7?a3:b2.b,a9=b5==null?a3:b5.b,b0=a5==null
if(b0)x=a3
else{w=a5.a
w=new B.a3(w,new A.arA(a4),B.F(w).h("a3<1>")).dd(0,0,new A.arB())
x=w}if(x==null)x=0
v=b0?a3:C.c.dd(a5.a,0,new A.arC())
if(v==null)v=0
u=x>0?x:v
t=(b0?a3:a5.a.length!==0)===!0?C.c.gR(a5.a).a:"-"
s=b0?a3:C.c.dd(a5.c,0,new A.arH())
if(s==null)s=0
b0=a6==null
if(b0)r=a3
else{w=a6.a
w=new B.a3(w,new A.arI(a4),B.F(w).h("a3<1>")).dd(0,0,new A.arJ())
r=w}if(r==null)r=0
q=b0?a3:C.c.dd(a6.a,0,new A.arK())
if(q==null)q=0
p=r>0?r:q
if(!b0&&a6.b.length!==0){w=a6.b
o=new B.y(w,new A.arL(),B.F(w).h("y<1,m>")).c6(0,new A.arM())/w.length}else o=0
n=(b0?a3:a6.a.length!==0)===!0?C.c.gR(a6.a).a:"-"
b0=a8==null
w=!b0
m=!0
if(w)if((a7?a3:b2.a===C.fB)!==!0){l=(a7?a3:b2.a===C.cl)===!0
m=l}k=a3
if(w)for(a7=a8.c,l=a7.length,j=0;j<a7.length;a7.length===l||(0,B.z)(a7),++j){i=a7[j]
if(A.a4g(i.a)===a4){k=i
break}}h=(b0?a3:a8.b.length!==0)===!0?C.c.gR(a8.b).b:0
if(w&&a8.a.length!==0){a7=a8.a
g=new B.y(a7,new A.arN(),B.F(a7).h("y<1,m>")).c6(0,new A.arO())/a7.length}else g=0
f=(b0?a3:a8.b.length!==0)===!0?C.c.gR(a8.b).a:"-"
a7=a9==null
if(a7)e=a3
else{b0=a9.c
w=B.F(b0)
l=w.h("dP<1,m>")
l=B.ks(new B.dP(new B.a3(b0,new A.arD(a4),w.h("a3<1>")),new A.arE(),l),l.h("p.E"),y.y).vK(0,new A.arF(),new A.arG())
e=l}if(e==null)e=(a7?a3:a9.c.length!==0)===!0?C.c.gR(a9.c).d:0
d=A.b6A(u,p,m?0:h)
a7=A.yY(u)
b0=A.yY(p)
w=C.d.K(o,1)
l=m?"Reddit temporalmente no disponible":"Pulso de comunidad"
a0=m?"Reddit no disponible. Fallback con cach\xe9.":"Tema: "+f+" ("+A.yY(h)+" menciones)."
a1=B.b([new A.l4("Dominio en actividad t\xe9cnica","GitHub "+a7+", StackOverflow "+b0+"."),new A.l4("Calidad de discusi\xf3n","Aceptaci\xf3n media en StackOverflow: "+w+"%."),new A.l4(l,a0)],y.E)
a0=A.yY(u)
l=A.yY(s)
w=A.yY(p)
b0=C.d.K(o,0)
a7=A.aSV(n)
a2=(k==null?a3:k.c)!=null?"#"+B.o(k.c):A.yY(h)
return new A.aFt(u,a0,t,l,p,w,b0+"%",a7,a2,C.d.K(g,0)+"%",f,e,m,A.aMg(d[0]),A.aMg(d[1]),A.aMg(d[2]),a1)},
b6A(d,e,f){var x=y.n,w=C.c.c6(B.b([d,e,f,1],x),new A.arT())
return B.b([d/w*100,e/w*100,f/w*100],x)},
aMg(d){var x=y.w
x=B.x(new B.y(B.b([0.36,0.48,0.61,0.74,0.86,1],y.n),new A.arx(d),x),x.h("X.E"))
return x},
yY(d){if(d>=1e6)return C.d.K(d/1e6,1)+"M"
if(d>=1000)return C.d.K(d/1000,1)+"k"
return C.e.k(d)},
KL(d,e,f,g,h,i,j,k,l,m,n){return new A.a19(f,e,l,i,h,g,j,m,k,n,d,null)},
v6:function v6(d,e){this.e=d
this.a=e},
arU:function arU(d,e,f,g,h,i,j){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j},
ari:function ari(d){this.a=d},
ary:function ary(d,e){this.a=d
this.b=e},
arl:function arl(d,e,f){this.a=d
this.b=e
this.c=f},
ark:function ark(){},
arm:function arm(){},
arn:function arn(){},
aro:function aro(){},
arp:function arp(){},
arq:function arq(){},
arr:function arr(d,e,f){this.a=d
this.b=e
this.c=f},
arw:function arw(d,e){this.a=d
this.b=e},
ars:function ars(d){this.a=d},
arP:function arP(d){this.a=d},
art:function art(){},
aru:function aru(){},
arv:function arv(){},
arz:function arz(){},
arQ:function arQ(){},
arR:function arR(){},
arA:function arA(d){this.a=d},
arB:function arB(){},
arC:function arC(){},
arH:function arH(){},
arI:function arI(d){this.a=d},
arJ:function arJ(){},
arK:function arK(){},
arL:function arL(){},
arM:function arM(){},
arN:function arN(){},
arO:function arO(){},
arD:function arD(d){this.a=d},
arE:function arE(){},
arF:function arF(){},
arG:function arG(){},
arT:function arT(){},
arx:function arx(d){this.a=d},
Le:function Le(d,e){this.c=d
this.a=e},
a19:function a19(d,e,f,g,h,i,j,k,l,m,n,o){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.z=l
_.Q=m
_.as=n
_.a=o},
aDS:function aDS(d,e,f,g,h,i){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i},
IY:function IY(d,e){this.c=d
this.a=e},
az9:function az9(d){this.a=d},
l4:function l4(d,e){this.a=d
this.b=e},
aFt:function aFt(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n
_.Q=o
_.as=p
_.at=q
_.ax=r
_.ay=s
_.ch=t},
a4g(d){var x,w="cplusplus",v=C.b.au(d.toLowerCase())
if(v.length===0)return""
v=B.bs(v,"c#","csharp")
v=B.bs(v,"#","sharp")
v=B.bs(v,"c-plus-plus",w)
v=B.bs(v,"c++",w)
v=B.bs(v,"++","plusplus")
v=B.bs(v,"+","plus")
x=B.bd("[^a-z0-9]+",!0,!1,!1)
return B.bs(v,x,"")}},D,H,F,E,G,N,O,L
J=c[1]
B=c[0]
C=c[2]
K=c[25]
I=c[21]
M=c[23]
A=a.updateHolder(c[6],A)
D=c[26]
H=c[10]
F=c[17]
E=c[11]
G=c[15]
N=c[8]
O=c[18]
L=c[19]
A.Fk.prototype={
R9(d){switch(d.a){case 6:return!0
case 1:case 2:case 0:case 4:case 3:case 5:return!1}},
srk(d){var x=this,w=x.n
if(w===d)return
x.n=d
if(x.R9(w)||x.R9(d))x.a3()
else{x.a4=x.bC=null
x.ar()}},
seR(d){var x=this
if(x.ag.j(0,d))return
x.ag=d
x.B=x.a4=x.bC=null
x.ar()},
sbE(d){var x=this
if(x.bL==d)return
x.bL=d
x.B=x.a4=x.bC=null
x.ar()},
cn(d){var x,w=this.n$
if(w!=null){x=w.ah(C.Q,F.kP,w.gcg())
switch(this.n.a){case 6:return d.aV(new B.a2(0,d.b,0,d.d).v8(x))
case 1:case 2:case 0:case 4:case 3:case 5:return d.v8(x)}}else return new B.G(B.H(0,d.a,d.b),B.H(0,d.c,d.d))},
bq(){var x,w,v=this,u=v.n$
if(u!=null){u.c5(F.kP,!0)
switch(v.n.a){case 6:u=y.e
x=u.a(B.v.prototype.gZ.call(v))
w=new B.a2(0,x.b,0,x.d).v8(v.n$.gu())
v.fy=u.a(B.v.prototype.gZ.call(v)).aV(w)
break
case 1:case 2:case 0:case 4:case 3:case 5:v.fy=y.e.a(B.v.prototype.gZ.call(v)).v8(v.n$.gu())
break}v.a4=v.bC=null}else{u=y.e.a(B.v.prototype.gZ.call(v))
v.fy=new B.G(B.H(0,u.a,u.b),B.H(0,u.c,u.d))}},
HA(){var x,w,v,u,t,s,r,q,p,o,n=this
if(n.a4!=null)return
x=n.n$
if(x==null){n.bC=!1
x=new B.b8(new Float64Array(16))
x.dz()
n.a4=x}else{w=n.B
if(w==null)w=n.B=n.ag
v=x.gu()
u=B.aVl(n.n,v,n.gu())
x=u.b
t=u.a
s=v.a
r=v.b
q=w.Km(t,new B.A(0,0,0+s,0+r))
p=n.gu()
o=w.Km(x,new B.A(0,0,0+p.a,0+p.b))
p=q.a
n.bC=q.c-p<s||q.d-q.b<r
r=B.pR(o.a,o.b,0)
r.nL(x.a/t.a,x.b/t.b,1,1)
r.dv(-p,-q.b,0,1)
n.a4=r}},
TF(d,e){var x,w,v,u,t=this,s=t.a4
s.toString
x=B.QX(s)
if(x==null){s=t.cx
s===$&&B.a()
w=t.a4
w.toString
v=B.f1.prototype.geo.call(t)
u=t.ch.a
return d.rJ(s,e,w,v,u instanceof B.kX?u:null)}else t.hg(d,e.S(0,x))
return null},
aA(d,e){var x,w,v,u,t=this
if(t.n$==null||t.gu().ga2(0)||t.n$.gu().ga2(0))return
t.HA()
x=t.bC
x.toString
if(x&&t.dH!==C.k){x=t.cx
x===$&&B.a()
w=t.gu()
v=t.ch
u=v.a
u=u instanceof B.p4?u:null
v.sao(d.l7(x,e,new B.A(0,0,0+w.a,0+w.b),t.galg(),t.dH,u))}else t.ch.sao(t.TF(d,e))},
cs(d,e){var x,w=this
if(!w.gu().ga2(0)){x=w.n$
x=x==null?null:x.gu().ga2(0)
x=x===!0}else x=!0
if(x)return!1
w.HA()
return d.uR(new A.akP(w),e,w.a4)},
ns(d){return!this.gu().ga2(0)&&!d.gu().ga2(0)},
cN(d,e){var x
if(!(!this.gu().ga2(0)&&!d.gu().ga2(0)))e.xk()
else{this.HA()
x=this.a4
x.toString
e.dX(x)}}}
A.Py.prototype={
aE(d){var x=new A.Fk(this.e,this.f,B.d2(d),C.k,null,new B.aK(),B.ag(y.v))
x.aD()
x.saU(null)
return x},
aK(d,e){e.srk(this.e)
e.seR(this.f)
e.sbE(B.d2(d))
if(C.k!==e.dH){e.dH=C.k
e.ar()
e.b3()}}}
A.mi.prototype={}
A.yK.prototype={}
A.U6.prototype={}
A.k2.prototype={}
A.U7.prototype={}
A.aq3.prototype={}
A.U4.prototype={}
A.U5.prototype={}
A.qt.prototype={
nj(){var x=0,w=B.Q(y.k),v,u=2,t=[],s=this,r,q,p,o,n,m
var $async$nj=B.R(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return B.S(s.a.nj(),$async$nj)
case 7:r=e
q=A.b5K(r)
if(q.r.length===0){o=B.rR("technology_profiles.json has no profiles",y.m)
v=o
x=1
break}o=B.pb(q,y.m)
v=o
x=1
break
u=2
x=6
break
case 4:u=3
m=t.pop()
p=B.a6(m)
o=B.rR("technology profiles load failed: "+B.o(p),y.m)
v=o
x=1
break
x=6
break
case 3:x=2
break
case 6:case 1:return B.O(v,w)
case 2:return B.N(t.at(-1),w)}})
return B.P($async$nj,w)}}
A.v6.prototype={
oq(a3,a4){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i=null,h=a4.cF($.aJU(),y.L),g=a4.cF($.aJY(),y.B),f=a4.cF($.aJX(),y.r),e=a4.cF($.aJZ(),y.W),d=a4.cF($.AQ(),y.G),a0=a4.cF($.aZM(),y.Z),a1=B.fT(h,y.a),a2=a1==null?i:a1.a
a1=B.fT(g,y.x)
x=a1==null?i:a1.a
a1=B.fT(f,y.u)
w=a1==null?i:a1.a
a1=B.fT(e,y.S)
v=a1==null?i:a1.a
a1=B.fT(d,y.J)
u=a1==null?i:a1.a
a1=B.fT(a0,y.k)
t=a1==null?i:a1.a
s=u==null?i:u.b
a1=this.e
r=B.jp(a1,0,a1.length,C.a_,!1)
q=B.AG(r)
p=t==null?i:t.b
o=A.b6C(p,q)
a1=o!=null
n=a1&&p!=null
m=a1&&C.b.au(o.b).length!==0?o.b:A.aSV(r)
l=A.b6v(a2,w,x,r,v)
k=a0.gh4()&&!n
if(!n)j=(h.gh4()||g.gh4()||e.gh4())&&l.a===0&&l.e===0
else j=!1
if(k||j)return this.aa2(a3,m)
return B.eh(new A.arU(this,o,p,s,m,l,t))},
Po(d,e){var x=null,w=B.aG(999),v=e.as,u=v==null,t=u?x:v.Am(C.ao)
t=B.aSC(D.LX,D.a1Q,new A.ari(d),B.aqc(x,x,C.pT,x,x,x,x,x,x,C.fn,x,C.S,C.KR,x,new B.cV(w,D.EF),x,x,C.mV,t,x))
return B.bU(C.F,B.b([t,B.Z("> An\xe1lisis por tecnolog\xeda",x,x,x,x,u?x:v.fR(C.aj,C.ao),x,x)],y.p),C.di,8,8)},
Ei(d,e){return B.eh(new A.ary(e,d))},
a9R(d,e){var x,w,v,u,t,s,r,q,p,o=null,n=d.as
if(n.length<2)return B.eG(B.Z("Hist\xf3rico insuficiente para graficar.",o,o,o,o,B.c3(o,o,C.aj,o,o,o,o,o,o,o,o,13,o,o,o,o,o,!0,o,o,o,o,o,o,o,o),o,o),o,o)
x=d.y.c
w=d.z.c
v=d.Q.c
if(!x&&!w&&!v)return B.eG(B.Z("No hay fuentes disponibles para graficar.",o,o,o,o,O.Dd,o,o),o,o)
u=C.c.dd(n,0,new A.arl(x,w,v))
t=u<=0?100:Math.ceil(u*1.1/10)*10
s=n.length
r=s-1
q=s<=6?1:C.d.jU(s/5)
s=B.b([],y.t)
if(x)s.push(H.lL(o,3,o,C.as,0.35,o,F.cJ,o,!0,!1,!1,!1,F.cL,!1,10,F.cS,!0,C.c3,A.aMf(n,new A.arm())))
if(w)s.push(H.lL(o,3,o,I.d0,0.35,D.rq,F.cJ,o,!0,!1,!1,!1,F.cL,!1,10,F.cS,!0,C.c3,A.aMf(n,new A.arn())))
if(v)s.push(H.lL(o,3,o,G.bn,0.35,o,F.cJ,o,!0,!1,!1,!1,F.cL,!1,10,F.cS,!0,C.c3,A.aMf(n,new A.aro())))
s=B.cj(H.aec(H.DZ(o,o,o,F.j7,E.nh(o,!1),G.me,G.fP,new E.jI(!0,!0,o,new A.arp(),E.hY(),!1,o,E.rg(),E.hY()),s,F.ri,r,t,0,0,G.hb,F.j8,new E.iU(!0,new E.e1(16,o,new E.e8(!0,new A.arq(),36,t/4,!0,!0),!0),G.b6,G.b6,new E.e1(16,o,new E.e8(!0,new A.arr(r,q,n),22,1,!0,!0),!0)))))
p=B.b([],y.h)
if(x)p.push(M.pg)
if(w)p.push(D.H0)
if(v)p.push(D.GO)
return B.aH(B.b([s,C.T,H.a6r(p)],y.p),C.B,C.l,C.o)},
aa2(d,e){return B.eh(new A.arw(this,e))},
Ek(){return B.cC(E.w9(new B.ax(C.d4,B.aH(D.O1,C.q,C.l,C.o),null),C.az),null,260)},
Pw(d,e){var x=null,w=d.aO(0.12),v=B.aG(999),u=B.cs(d.aO(0.35),1)
return new B.dl(C.kQ,B.aA(x,B.Z(e,x,x,x,!0,B.c3(x,x,d,x,x,x,x,x,x,x,x,12,x,x,C.z,x,x,!0,x,x,x,x,x,x,x,x),x,x),C.k,x,x,new B.au(w,x,u,v,x,x,C.r),x,x,x,x,C.em,x,x,x),x)},
aal(d,e){var x=null,w=new B.bm(x,y.R)
return B.Hc(B.jM(C.bS,d,C.an,!1,x,x,x,x,x,x,x,x,x,x,x,x,x,x,new A.arP(w),x,x,x,x,x,x),x,w,e,x,C.fE,x,C.R)},
aa1(d){var x=null,w=A.aMh(d.at),v=A.aMh(d.ax),u=A.aMh(d.ay),t=E.nh(x,!1),s=B.b([H.lL(x,3,x,C.as,0.35,x,F.cJ,x,!0,!1,!1,!1,F.cL,!1,10,F.cS,!0,C.c3,w),H.lL(x,3,x,I.d0,0.35,D.rq,F.cJ,x,!0,!1,!1,!1,F.cL,!1,10,F.cS,!0,C.c3,v)],y.t)
if(!d.as)s.push(H.lL(x,3,x,G.bn,0.35,x,F.cJ,x,!0,!1,!1,!1,F.cL,!1,10,F.cS,!0,C.c3,u))
return H.aec(H.DZ(x,x,x,F.j7,t,G.me,G.fP,new E.jI(!0,!0,x,new A.art(),E.hY(),!1,x,E.rg(),E.hY()),s,F.ri,5,100,0,0,G.hb,F.j8,new E.iU(!0,new E.e1(16,x,new E.e8(!0,new A.aru(),34,20,!0,!0),!0),G.b6,G.b6,new E.e1(16,x,new E.e8(!0,new A.arv(),22,1,!0,!0),!0))))}}
A.Le.prototype={
I(d){var x,w,v,u,t=null,s=this.c,r=s>=45&&s<70
if(s>=70)x=D.l5
else x=r?C.d1:C.bo
w=x.aO(0.12)
v=B.aG(12)
u=B.cs(x.aO(0.35),1)
return B.aA(t,B.aH(B.b([D.a1z,B.Z(C.d.K(s,2),t,t,t,t,B.c3(t,t,x,t,t,t,t,t,t,t,t,30,t,t,C.bI,t,t,!0,t,t,t,t,t,t,t,t),t,t)],y.p),C.dC,C.l,C.o),C.k,t,t,new B.au(w,t,u,v,t,t,C.r),t,t,t,t,D.KS,t,t,t)}}
A.a19.prototype={
I(d){var x,w=this,v=w.as,u=v?w.c:D.IU,t=v?C.a8:C.aj,s=v?C.aj:C.bh,r=C.b.au(w.w)
if(!v)x=w.PB("No disponible",C.bo)
else{v=w.r
x=v.length!==0?w.PB(v,u):null}return B.eh(new A.aDS(w,u,t,x,r,s))},
PB(d,e){var x=null,w=e.aO(0.12),v=B.aG(999),u=B.cs(e.aO(0.35),1)
return B.aA(x,B.Z(d,x,x,x,x,B.c3(x,x,e,x,x,x,x,x,x,x,x,11,x,x,C.z,x,x,!0,x,x,x,x,x,x,x,x),x,x),C.k,x,x,new B.au(w,x,u,v,x,x,C.r),x,x,x,x,C.iz,x,x,x)}}
A.IY.prototype={
I(d){var x,w=null,v=B.a_(d).ok,u=B.aG(14),t=B.cs(C.aN,1),s=this.c
if(s.length===0){s=v.z
s=B.b([B.Z("Sin insights disponibles.",w,w,w,w,s==null?w:s.c0(C.aj),w,w)],y.p)}else{x=B.F(s).h("y<1,ax>")
s=B.x(new B.y(s,new A.az9(v),x),x.h("X.E"))}return B.aA(w,B.aH(s,C.q,C.l,C.o),C.k,w,w,new B.au(C.j,w,t,u,w,w,C.r),w,w,w,w,C.d4,w,w,w)}}
A.l4.prototype={}
A.aFt.prototype={}
var z=a.updateTypes(["m(k2)","fF(m)","aX(m,ea)","aR(m,ea)","kX?(kL,h)","yK(a7<@,@>)","k2(a7<@,@>)","qt(fL<qt>)","a4<aW<mi>>(hx<aW<mi>>)","m(m,k2)","bS(aL<f,k2>)","bS(aL<f,m>)","ax(l4)"])
A.akP.prototype={
$2(d,e){return this.a.tx(d,e)},
$S:11}
A.aq5.prototype={
$1(d){return A.b5J(d.bh(0,y.N,y.z))},
$S:z+5}
A.aq4.prototype={
$1(d){var x,w,v,u=d.bh(0,y.N,y.z),t=u.i(0,"date")
t=t==null?null:J.T(t)
if(t==null)t=""
A.vF(u.i(0,"trend_score"))
x=A.vF(u.i(0,"github_score"))
w=A.vF(u.i(0,"so_score"))
v=A.vF(u.i(0,"reddit_score"))
A.a42(u.i(0,"ranking"))
A.a3R(u.i(0,"fuentes"),0)
A.aNb(u.i(0,"available_source_codes"))
return new A.k2(t,x,w,v)},
$S:z+6}
A.aI2.prototype={
$1(d){return J.T(d)},
$S:81}
A.aJy.prototype={
$1(d){return new A.qt(d.cF($.vL(),y.d))},
$S:z+7}
A.aJx.prototype={
$1(d){return this.a2p(d)},
a2p(d){var x=0,w=B.Q(y.k),v
var $async$$1=B.R(function(e,f){if(e===1)return B.N(f,w)
for(;;)switch(x){case 0:v=d.cF($.aZN(),y.I).nj()
x=1
break
case 1:return B.O(v,w)}})
return B.P($async$$1,w)},
$S:z+8}
A.arU.prototype={
$2(b3,b4){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,a0=null,a1="StackOverflow",a2="Contribuci\xf3n por fuente",a3="Prev",a4="Delta",a5="Hallazgos principales",a6=b4.b<980,a7=a6?16:24,a8=d.b,a9=a8!=null&&d.c!=null,b0=d.a,b1=d.d,b2=d.e
if(a9){a9=d.c
x=B.a_(b3).ok
w=A.aSW(a9.d)
v=A.aSW(a9.e)
u=A.b6u(v,w)
a9=a8.e
t=A.arj(a9,"pts")
s=a8.w
r=A.b6x(s)
q=a8.at
p=B.b([],y.E)
o=q.a
if(o!=null)p.push(new A.l4("Fuente dominante",A.aMi(o.d)))
p.push(new A.l4("Cobertura",A.aMi(q.b.c)))
p.push(new A.l4("Momentum",A.aMi(A.b6z(q.c.f))))
q=b1==null?a0:b1.f
n=x.e
if(n==null)n=a0
else n=n.An(C.a8,a6?28:32,C.bI)
n=B.Z(b2,a0,a0,a0,a0,n,a0,a0)
b2=E.a44(b1)
m=x.z
b2=B.Z(b2,a0,a0,a0,a0,m==null?a0:m.c0(C.ai),a0,a0)
b1=E.a45(b1)
m=x.Q
l=m==null
k=y.p
b1=B.b([n,C.ab,b2,C.bz,B.Z(b1,a0,a0,a0,a0,l?a0:m.c0(C.aj),a0,a0)],k)
if(u.length!==0)b1.push(B.Z(u,a0,a0,a0,a0,l?a0:m.c0(C.aj),a0,a0))
b1.push(C.T)
b2=b0.Pw(C.fn,"Ranking global #"+a8.f)
s=b0.Pw(A.b6B(s),r)
a9=A.b6w(a9)
n=a9.aO(0.12)
m=B.aG(999)
l=B.cs(a9.aO(0.35),1)
b1.push(B.bU(C.F,B.b([b2,s,new B.dl(K.oT,B.aA(a0,B.bU(C.F,B.b([B.Z(t,a0,a0,a0,!0,B.c3(a0,a0,a9,a0,a0,a0,a0,a0,a0,a0,a0,12,a0,a0,C.z,a0,a0,!0,a0,a0,a0,a0,a0,a0,a0,a0),a0,a0),b0.aal(B.eg(C.mk,a9,a0,14),"Puntaje total = GH 40% \xb7 SO 35% \xb7 RD 25%.")],k),C.di,2,6),C.k,a0,a0,new B.au(n,a0,l,m,a0,a0,C.r),a0,a0,a0,a0,C.em,a0,a0,a0),a0)],k),C.N,8,8))
j=b0.Ei(B.aH(b1,C.q,C.l,C.o),new A.Le(a8.c,a0))
b1=B.b([b0.Po(b3,x),C.ab,j],k)
if(q===!0)b1.push(D.qa)
b1.push(C.by)
a9=a6?300:340
b0=b0.a9R(a8,a6)
b2=B.b([],y.s)
s=a8.y
q=s.c
if(q)b2.push("GitHub")
n=a8.z
m=n.c
if(m)b2.push(a1)
a8=a8.Q
l=a8.c
if(l)b2.push("Reddit")
b1.push(E.ln(a0,b0,a9,a0,"Grafico de lineas por fuente. Fuentes: "+(b2.length===0?"sin fuentes disponibles":C.c.b2(b2,", "))+". Eje X: snapshots. Eje Y: score por fuente.","C\xf3mo cambia el aporte de GitHub, StackOverflow y Reddit en cada corte.","Evoluci\xf3n del aporte por fuente"))
b1.push(C.by)
a9=x.r
b0=a9==null
b1.push(B.Z(a2,a0,a0,a0,a0,b0?a0:a9.fR(C.a8,C.z),a0,a0))
b1.push(C.T)
b2=A.Hh(s.d)
i=s.f
h=A.arj(i,"")
i=A.KL(q,"GH",C.as,A.aMj(s,v),h,b2,a3,a4,s.b,A.Hh(s.e),A.arS(i))
s=A.Hh(n.d)
b2=n.f
h=A.arj(b2,"")
b2=A.KL(m,"SO",I.d0,A.aMj(n,v),h,s,a3,a4,n.b,A.Hh(n.e),A.arS(b2))
n=A.Hh(a8.d)
s=a8.f
h=A.arj(s,"")
b1.push(B.bU(C.F,B.b([i,b2,A.KL(l,"RD",G.bn,A.aMj(a8,v),h,n,a3,a4,a8.b,A.Hh(a8.e),A.arS(s))],k),C.N,16,16))
b1.push(D.nF)
b1.push(B.Z(a5,a0,a0,a0,a0,b0?a0:a9.fR(C.a8,C.z),a0,a0))
b1.push(C.T)
b1.push(new A.IY(p,a0))
g=b1}else{a8=d.f
a9=d.r
a9=a9==null?a0:a9.c
x=B.a_(b3).ok
f=a9!=null&&C.b.au(a9).length!==0
a9=b1==null?a0:b1.f
s=x.e
if(s==null)s=a0
else s=s.An(C.a8,a6?28:32,C.bI)
s=B.Z(b2,a0,a0,a0,a0,s,a0,a0)
b2=E.a44(b1)
q=x.z
b2=B.Z(b2,a0,a0,a0,a0,q==null?a0:q.c0(C.ai),a0,a0)
b1=E.a45(b1)
q=x.Q
n=y.p
j=b0.Ei(B.aH(B.b([s,C.ab,b2,C.bz,B.Z(b1,a0,a0,a0,a0,q==null?a0:q.c0(C.aj),a0,a0)],n),C.q,C.l,C.o),new A.Le(a8.Q,a0))
q=B.b([b0.Po(b3,x),C.ab,j],n)
if(f)q.push(D.JE)
if(a9===!0)q.push(D.qa)
q.push(C.by)
a9=a6?280:320
q.push(E.ln("Fallback",b0.aa1(a8),a9,a0,a0,"Serie sintetizada para continuidad visual.","Evoluci\xf3n del aporte por fuente (fallback)"))
q.push(C.by)
a9=x.r
b0=a9==null
q.push(B.Z(a2,a0,a0,a0,a0,b0?a0:a9.fR(C.a8,C.z),a0,a0))
q.push(C.T)
b1=A.KL(!0,"GH",C.as,"Repositorios en tendencia. Se\xf1al t\xe9cnica m\xe1s estable.","",a8.b,"Top","Stars","GitHub",a8.c,a8.d)
b2=A.KL(!0,"SO",I.d0,"Preguntas recientes. Calidad de discusi\xf3n en la fuente.","",a8.f,"Aceptaci\xf3n","Top",a1,a8.r,a8.w)
s=a8.as
m=s?"Fuente no disponible. Continuidad visual con datos cacheados.":"Pulso de la comunidad. Tema dominante: "+a8.z+"."
q.push(B.bU(C.F,B.b([b1,b2,A.KL(!s,"RD",G.bn,m,"",a8.x,"Sentimiento","Tema","Reddit",a8.y,a8.z)],n),C.N,16,16))
q.push(D.nF)
q.push(B.Z(a5,a0,a0,a0,a0,b0?a0:a9.fR(C.a8,C.z),a0,a0))
q.push(C.T)
q.push(new A.IY(a8.ch,a0))
g=q}e=new B.ax(new B.ad(a7,20,a7,28),B.aH(g,C.q,C.l,C.o),a0)
if(B.ik(b3,a0)!=null)return e
return B.mb(e,a0,a0,a0,a0,C.a6)},
$S:245}
A.ari.prototype={
$0(){return B.tn(this.a).mj("/",null)},
$S:0}
A.ary.prototype={
$2(d,e){var x=null,w=new A.Py(C.EV,D.oG,this.a,x)
if(e.b<980)return B.aH(B.b([this.b,C.ce,new B.du(C.e9,x,x,w,x)],y.p),C.q,C.l,C.o)
return B.ca(B.b([B.cj(this.b),C.dX,new B.ia(1,C.co,new B.du(D.oG,x,x,w,x),x)],y.p),C.q,C.l,C.o,0)},
$S:140}
A.arl.prototype={
$2(d,e){var x=this.a?e.c:0,w=this.b?e.d:0,v=C.c.c6(B.b([x,w,this.c?e.e:0],y.n),new A.ark())
return v>d?v:d},
$S:z+9}
A.ark.prototype={
$2(d,e){return d>e?d:e},
$S:34}
A.arm.prototype={
$1(d){return d.c},
$S:z+0}
A.arn.prototype={
$1(d){return d.d},
$S:z+0}
A.aro.prototype={
$1(d){return d.e},
$S:z+0}
A.arp.prototype={
$1(d){return E.t7(C.aN,null,null,1)},
$S:z+1}
A.arq.prototype={
$2(d,e){var x=null
return B.Z(C.e.k(C.d.ct(d)),x,x,x,x,D.k3,x,x)},
$S:z+2}
A.arr.prototype={
$2(d,e){var x,w=this,v=null
if(d<0||d>w.a)return C.a3
x=C.d.aB(d)
if(C.e.bs(x,w.b)!==0&&x!==w.c.length-1)return C.a3
return new B.ax(L.fJ,B.Z(A.b6y(w.c[x].a),v,v,v,v,D.k3,v,v),v)},
$S:z+3}
A.arw.prototype={
$2(d,e){var x,w=null,v=e.b<980,u=v?16:24,t=v?300:340,s=this.a,r=B.a_(d).ok.r
r=r==null?w:r.fR(C.a8,C.z)
x=y.p
return B.mb(new B.ax(new B.ad(u,20,u,28),B.aH(B.b([D.Cv,C.ab,s.Ei(B.Z(this.b,w,w,w,w,r,w,w),D.Wx),C.T,B.bU(C.F,D.ND,C.N,8,10),C.by,N.aP4(t,0,3,!0),C.by,D.Cw,C.T,B.bU(C.F,B.b([s.Ek(),s.Ek(),s.Ek()],x),C.N,16,16),D.nF,D.Cw,C.T,E.w9(new B.ax(C.dD,B.aH(D.Ni,C.q,C.l,C.o),w),C.az)],x),C.q,C.l,C.o),w),w,w,w,w,C.a6)},
$S:100}
A.ars.prototype={
$1(d){return new E.bS(d.a,this.a.$1(d.b))},
$S:z+10}
A.arP.prototype={
$0(){var x=this.a.gM()
return x==null?null:x.Jv()},
$S:0}
A.art.prototype={
$1(d){return E.t7(C.aN,null,null,1)},
$S:z+1}
A.aru.prototype={
$2(d,e){var x=null
return B.Z(C.e.k(C.d.ct(d)),x,x,x,x,D.k3,x,x)},
$S:z+2}
A.arv.prototype={
$2(d,e){var x=null
if(d<0||d>5)return C.a3
return new B.ax(L.fJ,B.Z(D.NG[C.d.ct(d)],x,x,x,x,D.k3,x,x),x)},
$S:z+3}
A.arz.prototype={
$1(d){return new E.bS(d.a,d.b)},
$S:z+11}
A.arQ.prototype={
$1(d){return d.length!==0},
$S:9}
A.arR.prototype={
$1(d){return d[0].toUpperCase()+C.b.bl(d,1)},
$S:30}
A.arA.prototype={
$1(d){return A.a4g(d.a)===this.a},
$S:716}
A.arB.prototype={
$2(d,e){return d+e.b},
$S:126}
A.arC.prototype={
$2(d,e){return d+e.b},
$S:126}
A.arH.prototype={
$2(d,e){return d+e.b},
$S:717}
A.arI.prototype={
$1(d){return A.a4g(d.a)===this.a},
$S:79}
A.arJ.prototype={
$2(d,e){return d+e.b},
$S:144}
A.arK.prototype={
$2(d,e){return d+e.b},
$S:144}
A.arL.prototype={
$1(d){return d.b},
$S:249}
A.arM.prototype={
$2(d,e){return d+e},
$S:34}
A.arN.prototype={
$1(d){return d.f},
$S:718}
A.arO.prototype={
$2(d,e){return d+e},
$S:34}
A.arD.prototype={
$1(d){var x=d.b
return A.a4g(x.length!==0?x:d.c)===this.a},
$S:138}
A.arE.prototype={
$1(d){return d.d},
$S:719}
A.arF.prototype={
$1(d){return d!=null},
$S:720}
A.arG.prototype={
$0(){return null},
$S:42}
A.arT.prototype={
$2(d,e){return d>e?d:e},
$S:34}
A.arx.prototype={
$1(d){return C.d.cC(this.a*d,0,100)},
$S:1}
A.aDS.prototype={
$2(d,e){var x,w,v,u,t,s,r,q,p=this,o=null,n=e.b,m=isFinite(n)?Math.min(n,330):330
n=B.aG(14)
x=p.b
w=B.b([new B.b4(0,C.C,C.m.aO(0.04),C.jo,10)],y.V)
v=B.aA(o,o,C.k,o,o,new B.au(x,o,o,B.aG(999),o,o,C.r),o,10,o,D.KN,o,o,o,10)
u=p.a
t=p.c
s=y.p
r=B.b([B.Z(u.d+" \xb7 "+u.e,o,o,o,o,B.c3(o,o,t,o,o,o,o,o,o,o,o,13,o,o,C.z,o,1.3,!0,o,o,o,o,o,o,o,o),o,o)],s)
q=p.d
if(q!=null)C.c.O(r,B.b([C.ab,q],s))
v=B.ca(B.b([v,C.cu,B.cj(B.aH(r,C.q,C.l,C.o))],s),C.q,C.l,C.o,0)
r=u.as?u.f:"\u2014"
t=B.Z(r,o,o,o,o,B.c3(o,o,t,o,o,o,o,o,o,o,o,32,o,o,C.bI,o,o,!0,o,o,o,o,o,o,o,o),o,o)
r=p.e
if(r.length===0)r=" "
q=p.f
return B.aA(o,B.aH(B.b([v,C.aV,t,C.cv,new B.dl(D.ET,B.Z(r,o,o,o,o,B.c3(o,o,q,o,o,o,o,o,o,o,o,13,o,o,o,o,1.35,!0,o,o,o,o,o,o,o,o),o,o),o),C.aV,D.JV,C.aV,B.bU(C.F,B.b([B.Z(u.x+": "+u.y,o,o,o,o,B.c3(o,o,q,o,o,o,o,o,o,o,o,13,o,o,o,o,o,!0,o,o,o,o,o,o,o,o),o,o),B.Z(u.z+": "+u.Q,o,o,o,o,B.c3(o,o,q,o,o,o,o,o,o,o,o,13,o,o,o,o,o,!0,o,o,o,o,o,o,o,o),o,o)],s),C.N,6,12)],s),C.q,C.l,C.o),C.k,o,o,new B.au(C.j,o,new B.dx(C.p,C.p,C.p,new B.bl(x,4,C.D,-1)),n,w,o,C.r),o,o,o,o,C.d4,o,o,m)},
$S:214}
A.az9.prototype={
$1(d){var x,w=null,v=B.aA(w,w,C.k,w,w,new B.au(C.as,w,w,B.aG(999),w,w,C.r),w,8,w,K.lz,w,w,w,8),u=this.a,t=u.x
t=t==null?w:t.fR(C.a8,C.z)
t=B.Z(d.a,w,w,w,w,t,w,w)
u=u.z
u=u==null?w:u.Yq(C.ai,1.3)
x=y.p
return new B.ax(D.KG,B.ca(B.b([v,C.jZ,B.cj(B.aH(B.b([t,C.bz,B.Z(d.b,w,w,w,w,u,w,w)],x),C.q,C.l,C.o))],x),C.q,C.l,C.o,0),w)},
$S:z+12};(function installTearOffs(){var x=a._instance_2u
x(A.Fk.prototype,"galg","TF",4)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.Fk,B.Fu)
w(B.jA,[A.akP,A.arU,A.ary,A.arl,A.ark,A.arq,A.arr,A.arw,A.aru,A.arv,A.arB,A.arC,A.arH,A.arJ,A.arK,A.arM,A.arO,A.arT,A.aDS])
x(A.Py,B.aR)
w(B.u,[A.mi,A.yK,A.U6,A.k2,A.U7,A.aq3,A.U4,A.U5,A.qt,A.l4,A.aFt])
w(B.fW,[A.aq5,A.aq4,A.aI2,A.aJy,A.aJx,A.arm,A.arn,A.aro,A.arp,A.ars,A.art,A.arz,A.arQ,A.arR,A.arA,A.arI,A.arL,A.arN,A.arD,A.arE,A.arF,A.arx,A.az9])
x(A.v6,B.wr)
w(B.jz,[A.ari,A.arP,A.arG])
w(B.ak,[A.Le,A.a19,A.IY])})()
B.r5(b.typeUniverse,JSON.parse('{"Fk":{"E":[],"aJ":["E"],"v":[],"ao":[]},"Py":{"aR":[],"ap":[],"e":[]},"v6":{"a0":[],"e":[]},"Le":{"ak":[],"e":[]},"a19":{"ak":[],"e":[]},"IY":{"ak":[],"e":[]}}'))
var y=(function rtii(){var x=B.a8
return{L:x("cH<aW<iV>>"),r:x("cH<aW<jX>>"),G:x("cH<aW<fp>>"),B:x("cH<aW<hJ>>"),Z:x("cH<aW<mi>>"),W:x("cH<aW<fO>>"),e:x("a2"),v:x("dS"),a:x("aW<iV>"),u:x("aW<jX>"),J:x("aW<fp>"),x:x("aW<hJ>"),k:x("aW<mi>"),S:x("aW<fO>"),d:x("n6"),D:x("bS"),V:x("n<b4>"),h:x("n<cI>"),t:x("n<cp>"),s:x("n<k>"),p:x("n<e>"),E:x("n<l4>"),n:x("n<m>"),R:x("bm<kW>"),j:x("M<@>"),f:x("a7<@,@>"),X:x("dP<k,k>"),w:x("y<m,m>"),N:x("k"),U:x("yK"),m:x("mi"),I:x("qt"),H:x("k2"),A:x("a3<k>"),z:x("@"),g:x("M<@>?"),Y:x("a7<@,@>?"),y:x("m?")}})();(function constants(){var x=a.makeConstList
D.oG=new B.e0(1,-1)
D.HW=new B.q(1,0.7490196078431373,0.8588235294117647,0.996078431372549,C.f)
D.EF=new B.bl(D.HW,1,C.D,-1)
D.ET=new B.a2(0,1/0,36,1/0)
D.GO=new E.cI("Reddit",G.bn,G.b_)
D.H0=new E.cI("StackOverflow",I.d0,G.b_)
D.l5=new B.q(1,0.08627450980392157,0.6392156862745098,0.2901960784313726,C.f)
D.IU=new B.q(1,0.796078431372549,0.8352941176470589,0.9607843137254902,C.f)
D.qa=new B.n8("Modo degradado: algunos datasets no estuvieron disponibles.",null,C.iu,null,null)
D.JE=new B.n8("Bridge no disponible. Usando datos legacy (CSV) para mantener el an\xe1lisis.",null,C.JD,null,null)
D.JV=new B.Cr(null,null)
D.KG=new B.ad(0,0,0,12)
D.KN=new B.ad(0,3,0,0)
D.KS=new B.ad(12,9,12,9)
D.LC=new B.by(62834,"MaterialIcons",null,!0)
D.LX=new B.lC(D.LC,18,null,null,null)
D.Wq=new E.hI(220,12,null)
D.Cv=new E.hI(180,12,null)
D.Wp=new E.hI(200,12,null)
D.Ni=x([D.Wq,C.aV,D.Cv,C.aV,D.Wp],y.p)
D.Wt=new E.mc(110,24,null)
D.Wu=new E.mc(120,24,null)
D.ND=x([G.Cx,D.Wt,D.Wu],y.p)
D.rq=x([6,4],B.a8("n<f>"))
D.NG=x(["Mar","May","Jul","Sep","Nov","Feb"],y.s)
D.Wm=new E.hI(120,14,null)
D.Wj=new E.uQ(20,null,C.hM,null)
D.Wn=new E.hI(160,12,null)
D.Wl=new E.hI(120,12,null)
D.O1=x([D.Wm,C.aV,D.Wj,C.T,D.Wn,C.aV,D.Wl],y.p)
D.nF=new B.cN(null,22,null,null)
D.Cw=new E.hI(200,16,null)
D.Wx=new E.mc(72,32,null)
D.CK=new A.U4("Cobertura no disponible.")
D.CL=new A.U5("Movimiento no disponible.")
D.k3=new B.r(!0,C.aj,null,null,null,null,11,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.a0g=new B.r(!0,C.aj,null,null,null,null,10,C.z,null,0.6,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.a1z=new B.aX("PUNTAJE DE TENDENCIA",null,D.a0g,null,null,null,null,null,null,null)
D.a1Q=new B.aX("Inicio",null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"bjH","aZN",()=>B.ul(new A.aJy(),y.I))
x($,"bjG","aZM",()=>B.wR(new A.aJx(),y.k))})()};
(a=>{a["vNx46Z0LFBcs5J3qspC/f/nz6Ls="]=a.current})($__dart_deferred_initializers__);