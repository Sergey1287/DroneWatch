/**
 * DroneWatch official-publication adapter (Cloudflare Worker).
 * Reads only public pages: French FR-Alert public alert listing and Russian EMERCOM operational RSS.
 * This is a publication aggregator, not a sensor or an emergency-warning replacement.
 */
const SOURCES = {
  fr: { name: "FR-Alert — France", url: "https://www.fr-alert.gouv.fr/les-alertes", kind: "public-alert" },
  ru: { name: "МЧС России — оперативная RSS", url: "https://mchs.gov.ru/deyatelnost/press-centr/operativnaya-informaciya/rss", kind: "official-publication" }
};
const HEADERS = { "User-Agent": "DroneWatch-Official-Source-Adapter/1.0 (+public-page reader)", "Accept": "text/html,application/rss+xml,application/xml,text/xml;q=0.9,*/*;q=0.8" };
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, OPTIONS", "Access-Control-Allow-Headers": "Content-Type", "Cache-Control": "no-store" };
function json(data, status=200) { return new Response(JSON.stringify(data, null, 2), {status, headers:{...cors,"Content-Type":"application/json; charset=utf-8"}}); }
function decode(s) { return String(s||"").replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g,"$1").replace(/<[^>]+>/g," ").replace(/&nbsp;|&#160;/gi," ").replace(/&amp;/g,"&").replace(/&quot;/g,'"').replace(/&#39;|&apos;/g,"'").replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&#(\d+);/g,(_,n)=>String.fromCharCode(Number(n))).replace(/\s+/g," ").trim(); }
function absolute(href, base) { try { return new URL(href,base).href; } catch { return base; } }
async function fetchText(url) { const r = await fetch(url,{headers:HEADERS,redirect:"follow",cf:{cacheTtl:120,cacheEverything:true}}); if(!r.ok) throw new Error(`HTTP ${r.status}`); return await r.text(); }
function parseRSS(xml) {
  const out=[]; const items=xml.match(/<item\b[\s\S]*?<\/item>/gi)||[];
  const keywords=/бпла|беспилот|дрон|воздушн.{0,30}(опас|тревог|угроз)|ракетн.{0,30}(опас|тревог|угроз)|атака|drone|uav|unmanned|air.?raid|menace|aérien|aérienne/i;
  for(const item of items.slice(0,80)) {
    const field=(name)=>{const m=item.match(new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${name}>`,'i'));return m?decode(m[1]):"";};
    const title=field("title"), description=field("description")||field("content:encoded"), link=field("link"), pub=field("pubDate")||field("dc:date");
    if(!title) continue;
    // The general EMERCOM feed is not exclusively an UAV alert feed. Filter relevant terms and clearly identify this as a publication.
    if(!keywords.test(`${title} ${description}`)) continue;
    out.push({id:`ru:${link||title}`,country:"RU",title,message:description.slice(0,1200),source:SOURCES.ru.name,sourceUrl:absolute(link,SOURCES.ru.url),time:pub && !Number.isNaN(Date.parse(pub))?new Date(pub).toISOString():new Date().toISOString(),type:"official-publication",status:"Официальная публикация; характер и актуальность проверяйте в первоисточнике",latitude:null,longitude:null});
  }
  return out;
}
function parseFR(html) {
  const out=[];
  // FR-Alert publishes a public listing. Parse anchors/text conservatively; do not infer coordinates or classify all alerts as UAV events.
  const anchors=html.match(/<a\b[^>]*href=["'][^"']+["'][^>]*>[\s\S]*?<\/a>/gi)||[];
  const seen=new Set();
  for(const a of anchors) {
    const hm=a.match(/href=["']([^"']+)["']/i); if(!hm) continue;
    const href=absolute(hm[1],SOURCES.fr.url); const title=decode(a);
    if(!title || title.length<8 || !/fr-alert\.gouv\.fr/i.test(href)) continue;
    if(href.replace(/\/$/,"")===SOURCES.fr.url || /^(Accueil|Les alertes|En savoir plus|Voir toutes les alertes)$/i.test(title)) continue;
    if(!/alerte|alert|commune|zone|département|risque|incendie|pluie|inondation|séisme|autre|météo|météorologie|sécurité/i.test(title)) continue;
    if(seen.has(href)) continue; seen.add(href);
    out.push({id:`fr:${href}`,country:"FR",title,message:"Alerte publiée sur le portail officiel FR-Alert. Consultez la source pour le texte complet et les consignes.",source:SOURCES.fr.name,sourceUrl:href,time:new Date().toISOString(),type:"public-alert",status:"Alerte publique; non spécifique aux drones par défaut",latitude:null,longitude:null});
    if(out.length>=40) break;
  }
  return out;
}
async function getSource(source, parser) {
  try { const body=await fetchText(source.url); const events=parser(body); return {ok:true,name:source.name,url:source.url,count:events.length,events,checkedAt:new Date().toISOString(),note:events.length?"Публикации получены; проверяйте подробности по ссылке":"Источник отвечает, подходящих публикаций в текущей выборке не найдено."}; }
  catch(e) { return {ok:false,name:source.name,url:source.url,count:0,events:[],checkedAt:new Date().toISOString(),error:String(e.message||e)}; }
}
export default {
 async fetch(request) {
   const url=new URL(request.url);
   if(request.method==="OPTIONS") return new Response(null,{status:204,headers:cors});
   if(url.pathname==="/api/health") return json({ok:true,service:"DroneWatch official-publication adapter",checkedAt:new Date().toISOString(),sources:Object.values(SOURCES)});
   if(url.pathname!=="/api/alerts") return json({error:"Not found",endpoints:["/api/health","/api/alerts"]},404);
   const [fr,ru]=await Promise.all([getSource(SOURCES.fr,parseFR),getSource(SOURCES.ru,parseRSS)]);
   const events=[...fr.events,...ru.events].sort((a,b)=>Date.parse(b.time)-Date.parse(a.time)).slice(0,100);
   return json({service:"DroneWatch official-publication adapter",checkedAt:new Date().toISOString(),sources:[{name:fr.name,url:fr.url,ok:fr.ok,count:fr.count,error:fr.error||null,note:fr.note||null},{name:ru.name,url:ru.url,ok:ru.ok,count:ru.count,error:ru.error||null,note:ru.note||null}],events,limitations:["This adapter aggregates public official publications only.","FR-Alert listings are general population alerts and are not specifically UAV alerts.","The EMERCOM RSS feed is not a complete nationwide real-time UAV warning API.","No coordinates are inferred. Events appear on the map only when official source data supplies coordinates.","A successful HTTP fetch or zero matching items does not mean there is no threat."]});
 }
};
