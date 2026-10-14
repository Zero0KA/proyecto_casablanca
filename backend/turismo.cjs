'use strict';
const express=require('express');
const { exigirCookie }=require('./sesiones.cjs');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function crearRouterTurismo(pool){
  const router=express.Router();
  function fallo(res,error){
    console.error('Error de turismo:',error.code||'sin código');
    const status=error.code==='42501'?401:error.code==='23505'?409:error.code==='23503'?404:['22023','23514'].includes(error.code)?400:503;
    const mensaje=status===401?'Inicia sesión con una cuenta habilitada.':status===409?'Ya tienes un recorrido abierto de esta ruta. Puedes consultarlo en Mi cuenta.':status===404?'La ruta o el recorrido no existe.':status===400?'La ruta no está disponible o no cumple las condiciones para esta operación.':'No se pudo completar la consulta. Comprueba la API y la BD.';
    return res.status(status).json({mensaje});
  }
  router.get('/rutas',async(_req,res)=>{
    try{const {rows}=await pool.query("SELECT * FROM public.listar_rutas_publicadas('es'::text)");return res.json(rows)}catch(error){return fallo(res,error)}
  });
  router.get('/rutas/:id',async(req,res)=>{
    if(!uuid.test(req.params.id))return res.status(400).json({mensaje:'Identificador de ruta inválido.'});
    try{
      const lista=await pool.query("SELECT * FROM public.listar_rutas_publicadas('es'::text)");
      const ruta=lista.rows.find(r=>r.ruta_id===req.params.id.toLowerCase());
      if(!ruta)return res.status(404).json({mensaje:'La ruta no existe o no está publicada.'});
      const paradas=await pool.query("SELECT * FROM public.listar_paradas_ruta_publicada($1::uuid,'es'::text)",[req.params.id]);
      return res.json({ruta,paradas:paradas.rows});
    }catch(error){return fallo(res,error)}
  });
  router.post('/rutas/:id/recorridos',exigirCookie,async(req,res)=>{
    if(!uuid.test(req.params.id))return res.status(400).json({mensaje:'Identificador de ruta inválido.'});
    try{const {rows}=await pool.query('SELECT public.iniciar_recorrido($1::text,$2::uuid) AS recorrido_id',[req.tokenSesion,req.params.id]);return res.status(201).json(rows[0])}catch(error){return fallo(res,error)}
  });
  router.get('/perfil',exigirCookie,async(req,res)=>{
    try{const {rows}=await pool.query('SELECT * FROM public.obtener_mi_perfil($1::text)',[req.tokenSesion]);if(!rows[0])return res.status(401).json({mensaje:'La sesión no está disponible.'});return res.json(rows[0])}catch(error){return fallo(res,error)}
  });
  router.get('/recorridos',exigirCookie,async(req,res)=>{
    const pagina=Number(req.query.pagina||1);
    if(!Number.isInteger(pagina)||pagina<1||pagina>10000)return res.status(400).json({mensaje:'Página inválida.'});
    try{const {rows}=await pool.query('SELECT * FROM public.listar_mis_recorridos($1::text,$2::integer,$3::integer)',[req.tokenSesion,20,(pagina-1)*20]);return res.json(rows)}catch(error){return fallo(res,error)}
  });
  router.post('/recorridos/:id/abandonar',exigirCookie,async(req,res)=>{
    if(!uuid.test(req.params.id))return res.status(400).json({mensaje:'Identificador de recorrido inválido.'});
    try{const {rows}=await pool.query("SELECT public.cerrar_recorrido($1::text,$2::uuid,'abandonado'::text) AS cerrado",[req.tokenSesion,req.params.id]);if(!rows[0].cerrado)return res.status(404).json({mensaje:'No tienes un recorrido abierto con ese identificador.'});return res.json({cerrado:true})}catch(error){return fallo(res,error)}
  });
  return router;
}
module.exports={crearRouterTurismo};
