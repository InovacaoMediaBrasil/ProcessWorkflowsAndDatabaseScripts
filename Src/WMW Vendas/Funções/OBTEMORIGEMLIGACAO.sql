USE [EDITORAWVWEBPRD]
GO
/****** Object:  UserDefinedFunction [dbo].[OBTEMORIGEMLIGACAO]    Script Date: 27/03/2017 17:45:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		RODRIGO LACALENDOLA
-- Create date: 2017-03-24
-- Description:	OBTEM A ORIGEM DA LIGAÇÃO (TELEFONE DE LIGAÇÃO)
-- =============================================
ALTER FUNCTION [dbo].[OBTEMORIGEMLIGACAO]
(
@CDATENDIMENTO INT
)
RETURNS VARCHAR(20)
AS
BEGIN

	-- variável para retornar a origem (numero de telefone - varchar)
	DECLARE @ORIGEM VARCHAR(20)
	
		-- buscar a informação no banco de dados da TOTALIP informando qual é o número de telefone que destino
		-- na total ip usa-se DESTINO (pois o cliente é a origem, e a total IP é o destino);
		SELECT TOP 1 @ORIGEM = destino FROM EDITORAWVWEBPRD.dbo.TBLVWATENDIMENTO vendas WITH(NOLOCK)
		INNER JOIN EDITORAWVWEBPRD.dbo.TBLVWUSUARIOCONFIG USU WITH(NOLOCK) ON USU.CDUSUARIO = vendas.CDUSUARIO
		INNER JOIN EDITORAWVWEBPRD.dbo.TBLVWUSUARIOREP REP WITH(NOLOCK) ON REP.CDUSUARIO = USU.CDUSUARIO
		INNER JOIN SANKHYA_PRODUCAO.sankhya.TGFVEN VEN WITH(NOLOCK) ON VEN.CODVEND = REP.CDREPRESENTANTE AND VEN.AD_SETORVEND = 'RECEPTIVO'
		INNER JOIN OpenQuery(TOTALIPDB,'SELECT id, origem, destino, duracao, billing, status, ramal, data, tipo_ligacao, 
        custo, custo_total, uniqueid
		FROM ligacoes_receptivo where data >= current_date - interval ''7 day''')  totalip on 
		nufone = case when len(SUBSTRING(origem,2,20)) <= 7  then '11'+origem else SUBSTRING(origem,2,20) end
		where CDSERVICO in ('v')
		AND CDATENDIMENTO = @CDATENDIMENTO

	-- Retorna o número de origem da ligação
	RETURN @ORIGEM

END
