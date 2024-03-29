USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_IMP_PED_MANUAL_WMWVENDAS]    Script Date: 21/08/2018 14:52:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* Runtime-info
Application: CadastroTelasAdicionais
Referer: http://erp.editorainovacao.com.br:8180/mge/flex/CadastroTelasAdicionais.swf/[[DYNAMIC]]/3
ResourceID: br.com.sankhya.core.cfg.TelasPersonalizadas
service-name: ActionButtonsSP.createStoredProcedure
uri: /mge/service.sbr
*/
/*
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2018-08-21
-- Description:	Realiza a importação de um pedido manualmente, através da tela Pedidos c/ Importação Pendente de pedidos gerados no WMW Vendas.
-- =============================================
*/

ALTER PROCEDURE [sankhya].[STP_IMP_PED_MANUAL_WMWVENDAS] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @PARAM_CODPEDORIGINAL INT,
       @FIELD_CODPED INT,
       @I INT,
	   @I_CDEMPRESA VARCHAR(20),
	   @I_CDREPRESENTANTE VARCHAR(20),
	   @I_FLORIGEMPEDIDOAUX CHAR(1),
	   @NUNOTA INT
BEGIN
	SET @PARAM_CODPEDORIGINAL = SANKHYA.ACT_INT_PARAM(@P_IDSESSAO, 'CODPEDORIGINAL')
	
	IF EXISTS (SELECT 1 FROM sankhya.TGFCAB WITH (NOLOCK) WHERE AD_PEDORIGINAL = @PARAM_CODPEDORIGINAL)
		RAISERROR('O pedido %i já se encontra no Sankhya, por favor cancele-o primeiro pelo Portal de Vendas para realizar a reimportação', 16, 1, @PARAM_CODPEDORIGINAL);
	IF NOT EXISTS(SELECT 1 FROM EDITORAWVWEBPRD.dbo.TBLVWPEDIDO WITH (NOLOCK) WHERE NUPEDIDO = @PARAM_CODPEDORIGINAL)
		RAISERROR('O pedido %i não foi localizado no WMW Vendas!', 16, 1, @PARAM_CODPEDORIGINAL);
	
	UPDATE EDITORAWVWEBPRD.dbo.TBLVWPEDIDO
	SET 
		dsMensagemControleErp = NULL,
		DtEnvioErp = NULL,
		flControleErp = NULL,
		HrEnvioErp = NULL,
		CDSTATUSPEDIDO = 2
	WHERE NUPEDIDO = @PARAM_CODPEDORIGINAL;

	SELECT	@I_CDEMPRESA = CDEMPRESA,
			@I_CDREPRESENTANTE = CDREPRESENTANTE,
			@I_FLORIGEMPEDIDOAUX = FLORIGEMPEDIDO
	FROM EDITORAWVWEBPRD.dbo.TBLVWPEDIDO WITH (NOLOCK)
	WHERE NUPEDIDO = @PARAM_CODPEDORIGINAL;

	EXEC EDITORAWVWEBPRD.dbo.PRIMPORTAPEDIDOS
		@CDEMPRESA = @I_CDEMPRESA, 
		@CDREPRESENTANTE = @I_CDREPRESENTANTE,
		@FLORIGEMPEDIDOAUX = @I_FLORIGEMPEDIDOAUX,
		@NUPEDIDOAUX = @PARAM_CODPEDORIGINAL,
		@RETORNO = OUTPUT;

	SELECT @NUNOTA = NUNOTA
	FROM sankhya.TGFCAB WITH (NOLOCK)
	WHERE AD_PEDORIGINAL = @PARAM_CODPEDORIGINAL;

	SET @P_MENSAGEM = 'Pedido <b>' + CAST(@PARAM_CODPEDORIGINAL AS VARCHAR) + '</b> reimportado com sucesso!<br /><br /><b>Número único:</b> ' + CAST(@NUNOTA AS VARCHAR);
END
