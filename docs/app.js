const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const brl=v=>Number(v).toLocaleString("pt-BR",{style:"currency",currency:"BRL"});
let tt; function toast(t){const e=$("#toast");e.textContent=t;e.classList.add("on");clearTimeout(tt);tt=setTimeout(()=>e.classList.remove("on"),2400);}

// neve na página inteira
(function(){const box=document.createElement("div");box.className="snowflakes";box.setAttribute("aria-hidden","true");const ch=["❅","❆","❄"];for(let i=0;i<18;i++){const f=document.createElement("div");f.className="snowflake";f.textContent=ch[i%3];f.style.left=(i*5.6+Math.random()*4)+"%";f.style.fontSize=(14+Math.random()*16)+"px";const d=9+Math.random()*8,s=3+Math.random()*3;f.style.animationDuration=d+"s,"+s+"s";f.style.animationDelay=(-Math.random()*d)+"s,"+(-Math.random()*s)+"s";box.appendChild(f);}document.body.appendChild(box);})();

// topo: título e contagem regressiva
function renderHero(){
  const e=S.event; $("#title").textContent=e.name||"Amigo Secreto de Natal";
  const parts=[]; if(e.count)parts.push(e.count+" participantes"); if(e.budget!=null&&e.budget!=="")parts.push("Presentes de até "+brl(e.budget)); if(e.note)parts.push(e.note);
  $("#intro").textContent=parts.length?parts.join(". ")+".":"Cadastrem o evento, sorteiem e deixem a lista de presentes sempre atualizada.";
  const c=$("#count");
  if(e.date){const d=Math.ceil((new Date(e.date+"T00:00:00")-new Date().setHours(0,0,0,0))/864e5);
    c.hidden=false; $("#days").textContent=Math.max(d,0);
    $("#dayslbl").textContent=d>1?"dias para a troca de presentes":d===1?"dia para a troca de presentes":d===0?"é hoje! Boa festa":"o evento já passou";
  } else c.hidden=true;
}

// evento
function fillEvent(){const e=S.event;$("#e-qtd").value=e.count||"";$("#e-nome").value=e.name;$("#e-data").value=e.date;$("#e-orc").value=e.budget;$("#e-obs").value=e.note;}
function renderPeople(){
  const l=$("#p-list"),n=S.people.length,q=S.event.count||0;$("#p-bar").style.width=(q?Math.min(100,n/q*100):0)+"%";$("#p-bar").classList.toggle("full",!!q&&n>=q);$("#p-prog").textContent=q?(n>=q?"Grupo completo: "+n+" de "+q+" participantes.":n+" de "+q+" participantes. Faltam "+(q-n)+"."):"Defina o número de participantes na aba Evento.";$("#p-add").disabled=!!S.pairs||!q||n>=q;
  if(!S.people.length){l.innerHTML='<li class="empty" style="display:block">Ninguém por aqui ainda. Adicione o primeiro participante.</li>';return;}
  l.innerHTML=S.people.map(p=>`<li><span class="av">${esc(p.name[0].toUpperCase())}</span><span class="grow">${esc(p.name)}</span>${S.pairs||!S.admin?"":`<button class="x" data-del="${p.id}" aria-label="Remover ${esc(p.name)}">×</button>`}</li>`).join("");
  $$("[data-del]").forEach(b=>b.onclick=()=>{if(confirm("Remover esta pessoa e sua lista?")) action("remover",{id:b.dataset.del});});
}
function renderDraw(){
  const n=S.people.length,st=$("#s-status");
  if(S.pairs){st.innerHTML='<span class="big">Sorteio realizado com '+n+' pessoas.</span><br>Cada participante já pode abrir a Minha área para ver quem tirou.';}
  else if(!S.event.name||!S.event.count){st.textContent="Primeiro cadastre o evento e o número de participantes na aba Evento.";}
  else if(n<S.event.count){st.textContent="O sorteio libera quando todos entrarem: faltam "+(S.event.count-n)+" de "+S.event.count+" participantes ("+n+" cadastrados).";}
  else st.innerHTML='<span class="big">Tudo pronto para sortear '+n+' pessoas.</span>';
  $("#s-go").hidden=!!S.pairs;$("#s-go").disabled=!(S.event.name&&S.event.count&&n===S.event.count);$("#s-redo").hidden=!S.pairs;
}
function wishHTML(w,del){const link=w.link?` <a href="${esc(w.link)}" target="_blank" rel="noopener noreferrer">ver link</a>`:"";return `<li class="wish"><span class="grow">${esc(w.text)}${link}</span>${del?`<button class="x" data-wd="${w.id}" aria-label="Remover ${esc(w.text)}">×</button>`:""}</li>`;}
function renderMe(){
  const p=byId(me);$("#m-hello").textContent="Olá, "+p.name;
  const d=$("#m-draw");
  if(!S.pairs){d.innerHTML='<div class="empty">O sorteio ainda não aconteceu. Enquanto isso, monte sua lista abaixo.</div>';}
  else{
    const r=byId(S.alvo);
    d.innerHTML=`<p class="sub" style="margin-bottom:0">Toque na etiqueta para descobrir quem você tirou.</p>
    <div class="scene"><div class="tag" id="tag" tabindex="0" role="button" aria-label="Revelar amigo secreto"><div class="face front">Toque para abrir</div><div class="face back"><div><small>Você tirou</small>${esc(r.name)}</div></div></div></div>
    <div id="r-box" hidden><h3 style="font-size:1.2rem">Lista de ${esc(r.name)}</h3><ul class="list">${r.wishes.length?r.wishes.map(w=>wishHTML(w,false)).join(""):'<li class="empty" style="display:block">Essa pessoa ainda não adicionou nada. Volte depois.</li>'}</ul></div>`;
    const t=$("#tag"),flip=()=>{t.classList.toggle("flip");$("#r-box").hidden=!t.classList.contains("flip");};
    t.onclick=flip;t.onkeydown=e=>{if(e.key==="Enter"||e.key===" "){e.preventDefault();flip();}};
  }
  $("#w-list").innerHTML=p.wishes.length?p.wishes.map(w=>wishHTML(w,true)).join(""):'<li class="empty" style="display:block">Sua lista está vazia. Adicione o que você gostaria de ganhar.</li>';
  $$("[data-wd]").forEach(b=>b.onclick=()=>{action("excluir",{id:b.dataset.wd});});
  $("#n-date").checked=!!p.notifyDate;$("#n-list").checked=!!p.notifyList;
}
const blank=()=>({event:{name:"",date:"",budget:"",note:""},people:[],pairs:false});
let S=blank(), me=null, db, account=null, busy=false;
const byId=id=>S.people.find(p=>p.id===id);
const params=new URLSearchParams(location.search);
const eventId=params.get("evento");
const draftId=crypto.randomUUID();
const invitation=new URLSearchParams(location.search).get("convite");
const message=t=>$("#message").textContent=t;
let editing=false;
let directoryLoaded=false;
let editorChanged=false;
$("#editor").oninput=()=>{editorChanged=true;};
function groupUrl(id){
  const url=new URL(location.href);
  url.search="";url.hash="";
  if(id)url.searchParams.set("evento",id);

  return url.href;
}
async function loadDirectory(){
  const {data,error}=await db.rpc("meus_eventos");
  if(error)throw error;
  const groups=$("#groups"),owned=$("#owned");
  groups.replaceChildren();owned.replaceChildren();
  for(const group of data){
    const link=document.createElement("a");
    link.textContent=group.nome||"Evento sem nome";
    link.href=groupUrl(group.id);
    const item=document.createElement("li");item.append(link);
    (group.participa?groups:owned).append(item);
  }
  directoryLoaded=true;
  $("#no-groups").hidden=groups.childElementCount>0;
  $("#managed").hidden=owned.childElementCount===0;
}
function showEditor(editExisting){
  editing=true;
  editorChanged=false;
  fillEvent();
  $("#e-qtd").min=Math.max(3,S.people.length);
  $("#e-qtd").disabled=!!S.pairs;
  $("#capacity-hint").textContent=S.pairs?"Para alterar as vagas, reabra o grupo na aba Sorteio. Isso apaga os pares atuais.":`Escolha de ${$("#e-qtd").min} a 50 vagas. Já há ${S.people.length} inscrição(ões).`;
  go("evento");
  $("#directory").hidden=true;$("#editor").hidden=false;
  $("#editor-title").textContent=editExisting?"Editar evento":"Criar evento";
  $("#e-save").textContent=editExisting?"Salvar alterações":"Criar evento";
  $("#e-nome").focus();
}
$("#novo").onclick=()=>showEditor(false);
$("#copy-invite").onclick=async()=>{
  const input=$("#invite");
  if(!S.admin||!input.value)return;
  try{
    await navigator.clipboard.writeText(input.value);
    toast("Link de convite copiado!");
  }catch{
    input.focus();input.select();
    toast("Link selecionado. Use a opção Copiar do seu dispositivo.");
  }
};

$("#cancel-editor").onclick=()=>{
  editing=false;$("#editor").hidden=true;
  if(S.id)location.assign(groupUrl(null));else $("#directory").hidden=false;
};
function paint(){
  renderHero();renderPeople();renderDraw();
  $("main").hidden=!account;$("nav").hidden=!account;
  $("#directory").hidden=editing||!!S.id;
  $("#no-groups").hidden=!directoryLoaded||$("#groups").childElementCount>0;
  $("#editor").hidden=!editing;
  for(const tab of $$("nav button"))tab.hidden=tab.dataset.t!=="evento"&&!S.id;
  $("#login").hidden=!!me;$("#area").hidden=!me;
  if(me)renderMe();else {$("#m-draw").replaceChildren();$("#w-list").replaceChildren();}
  $("#auth").hidden=!!account;$("#logout").hidden=!account;
  $("#session").textContent=account?account.email:"Entrar com e-mail";
  $("#m-out").hidden=true;
  $("#registration").hidden=!!me;
  $("#manager").hidden=!S.admin;
  if(S.admin){const url=new URL(groupUrl(null));url.searchParams.set("convite",S.convite);$("#invite").value=url.href;}
  $("#p-add").disabled ||= !!me||!account;
  $("#s-go").hidden ||= !S.admin;$("#s-redo").hidden ||= !S.admin;
}
async function action(acao,dados={}){
  if(!account||busy)return false;
  busy=true;
  try{
    const {data,error}=await db.rpc("natal",{acao,dados:{...dados,convite:invitation,evento:eventId}});
    if(error)throw error;
    if(acao==="criar"){location.assign(groupUrl(data.id));return true;}
    S=data.event?data:{...blank(),grupos:data.grupos||[]};me=S.me;paint();
    message(acao==="ler"?"":"Alteração salva.");
    return true;
  }catch(e){message(e.message);toast(e.message);return false;}finally{busy=false;}
}
function go(id){
  $$("nav button").forEach(b=>b.setAttribute("aria-selected",String(b.dataset.t===id)));
  $$("main section").forEach(s=>s.classList.toggle("on",s.id===id));
}
$$("nav button").forEach(b=>b.onclick=async()=>{
  const tab=b.dataset.t;
  if(busy)return;
  if(editing&&editorChanged&&!confirm("Sair sem salvar as alterações do evento?"))return;
  if(tab==="evento"&&(eventId||invitation)){location.assign(groupUrl(null));return;}
  editing=false;paint();go(tab);if(S.id)await action("ler");
});
$("#editor").onsubmit=async event=>{
  event.preventDefault();
  if(!$("#editor").reportValidity())return;
  if(!$("#e-data").value||!$("#e-nome").value.trim()||!$("#e-qtd").value)return toast("Informe nome, data e vagas.");
  if(await action(S.id?"evento":"criar",{novo:draftId,nome:$("#e-nome").value,data:$("#e-data").value,vagas:$("#e-qtd").value,valor:$("#e-orc").value,obs:$("#e-obs").value})){editing=false;paint();if(S.id)go("pessoas");}
};
$("#p-add").onclick=()=>{
  const nome=$("#p-nome").value.trim();
  if(!nome)return toast("Informe seu nome para entrar no grupo.");
  return action("entrar",{nome});
};
$("#s-go").onclick=()=>action("sortear");
$("#s-redo").onclick=()=>{if(confirm("Apagar os pares e reabrir o grupo?"))action("reabrir");};
function addWishRow(focus=false){
  const row=document.createElement("div");
  row.className="row";
  row.dataset.id=crypto.randomUUID();
  row.innerHTML='<label>Presente<input class="wish-name" maxlength="70" placeholder="Fone de ouvido"></label><label>Link (opcional)<input class="wish-link" maxlength="2048" placeholder="loja.com/produto"></label>';
  $("#wish-rows").append(row);
  if(focus)row.querySelector("input").focus();
}
addWishRow();
$("#wish-more").onclick=()=>addWishRow(true);
$("#wish-form").onsubmit=async event=>{
  event.preventDefault();
  if(!me||busy||$("#wish-fields").disabled)return;
  const itens=[];
  for(const row of document.querySelectorAll("#wish-rows .row")){
    const nameInput=row.querySelector(".wish-name"),linkInput=row.querySelector(".wish-link");
    const nome=nameInput.value.trim();
    let link=linkInput.value.trim();
    if(!nome&&!link)continue;
    if(!nome){nameInput.focus();return toast("Informe o presente desta linha.");}
    if(link){
      try{
        const url=new URL(/^[a-z][a-z0-9+.-]*:/i.test(link)?link:"https://"+link);
        if(!["http:","https:"].includes(url.protocol)||!url.hostname.includes(".")||url.href.length>2048)throw Error();
        link=url.href;
      }catch{linkInput.focus();return toast("Confira o endereço do presente.");}
    }
    itens.push({id:row.dataset.id,nome,link});
  }
  if(!itens.length)return toast("Informe pelo menos um presente.");
  $("#wish-fields").disabled=true;
  busy=true;
  try{
    const {error}=await db.rpc("salvar_presentes",{evento:S.id,itens});
    if(error)throw error;
    $("#wish-rows").replaceChildren();addWishRow();
  }catch(e){message(e.message);toast("Falha ao salvar. Seus presentes continuam no formulário.");return;}
  finally{busy=false;$("#wish-fields").disabled=false;}
  if(await action("ler"))toast(itens.length===1?"Presente salvo!":"Presentes salvos!");
};
$("#n-save").onclick=()=>action("avisos",{data:$("#n-date").checked,lista:$("#n-list").checked});
async function authTask(fn){
  try{const {error}=await fn();if(error)throw error;}catch(e){message(e.message);}
}
$("#send").onclick=()=>authTask(async()=>{
  if(!$("#email").reportValidity()||!$("#email").value.trim()){ $("#email").focus();return {}; }
  const result=await db.auth.signInWithOtp({email:$("#email").value.trim()});
  if(!result.error)message("Confira o código no seu e-mail e digite abaixo.");
  return result;
});
$("#verify").onclick=()=>authTask(async()=>{
  if(!/^\d+$/.test($("#code").value.trim())){toast("Digite o código recebido por e-mail.");$("#code").focus();return {}; }
  const result=await db.auth.verifyOtp({email:$("#email").value.trim(),token:$("#code").value.trim(),type:"email"});
  if(!result.error)location.reload();
  return result;
});
$("#logout").onclick=()=>authTask(async()=>{
  const result=await db.auth.signOut({scope:"local"});if(!result.error)location.reload();return result;
});
async function start(){
  paint();
  try{
    if(!window.NATAL_URL||!window.NATAL_KEY)throw Error("Preencha docs/config.js com a URL e a chave pública do Supabase.");
    db=supabase.createClient(window.NATAL_URL,window.NATAL_KEY);
    const {data,error}=await db.auth.getSession();if(error)throw error;
    account=data.session?.user;paint();
    if(account){
      if(eventId||invitation){
        if(await action("ler")){
          if(S.admin&&eventId)showEditor(true);
          else go(me&&!invitation?"eu":"pessoas");
        }
        else {$("#directory").hidden=true;const back=document.createElement("a");back.href=groupUrl(null);back.textContent="Voltar aos meus eventos";$("#message").append(" ",back);}
      }else{
        await loadDirectory();
      }
    }
    db.auth.onAuthStateChange((event,session)=>{
      if((session?.user?.id||null)!==(account?.id||null))location.reload();
    });
  }catch(e){message(e.message);}
}
start();
