USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_TGFPRO_SUBSTITUIR_PRODUTO]    Script Date: 25/09/2018 17:08:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* Runtime-info
Application: CadastroTelasAdicionais
Referer: http://erp.editorainovacao.com.br:8180/mge/flex/CadastroTelasAdicionais.swf/[[DYNAMIC]]/3
ResourceID: br.com.sankhya.core.cfg.DicionarioDados
service-name: ActionButtonsSP.createStoredProcedure
uri: /mge/service.sbr
*/
ALTER PROCEDURE [sankhya].[STP_TGFPRO_SUBSTITUIR_PRODUTO] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @PARAM_CODPRODSUBST VARCHAR(4000),
       @FIELD_CODPROD INT,
       @I INT,
	   @SACS INT,
	   @PEDORIGINAL INT,
	   @CODPARC INT,
	   @CDUSUARIO VARCHAR(30),
	   @CDSAC VARCHAR(10),
	   @MSG VARCHAR(500),
	   @NOMESGT VARCHAR(255)
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

	SET @PARAM_CODPRODSUBST = SANKHYA.ACT_TXT_PARAM(@P_IDSESSAO, 'CODPRODSUBST')

	SET @SACS = 0;

	SELECT @CDUSUARIO = CDUSUARIO
	FROM EDITORAWVWEBPRD.dbo.TBWMWUSUARIO AS U WITH (NOLOCK)
	WHERE U.DSLOGIN = (
		SELECT U.NOMEUSU 
		FROM sankhya.TSIUSU AS U WITH (NOLOCK) 
		WHERE U.CODUSU = @P_CODUSU
	) COLLATE SQL_Latin1_General_CP1_CI_AS

	SET @I = 1 -- A variável "I" representa o registro corrente.
	WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
	BEGIN
		-- Para obter o valor dos campos utilize uma das seguintes funções:
		--     ACT_INT_FIELD (Retorna o valor de um campo tipo NUMÉRICO INTEIRO))
		--     ACT_DEC_FIELD (Retorna o valor de um campo tipo NUMÉRICO DECIMAL))
		--     ACT_TXT_FIELD (Retorna o valor de um campo tipo TEXTO),
		--     ACT_DTA_FIELD (Retorna o valor de um campo tipo DATA)
		-- Estas funções recebem 3 argumentos:
		--     ID DA SESSÃO - Identificador da execução (Obtido através do parâmetro P_IDSESSAO))
		--     NÚMERO DA LINHA - Relativo a qual linha selecionada.
		--     NOME DO CAMPO - Determina qual campo deve ser obtido.
		SET @FIELD_CODPROD = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'CODPROD');

		SET @MSG = 'Substituir o produto ' + CAST(@FIELD_CODPROD AS VARCHAR) + ', sem reposição no momento.';
		IF @PARAM_CODPRODSUBST IS NOT NULL
		AND EXISTS (SELECT 1 FROM sankhya.TGFPRO WITH (NOLOCK) WHERE CODPROD = @PARAM_CODPRODSUBST)
		BEGIN
			SELECT @NOMESGT = sankhya.FN_CONCATENANOMEPRODUTO(@PARAM_CODPRODSUBST);
			SET @MSG = @MSG + 'Produto sugerido para substituição: ' + @PARAM_CODPRODSUBST + ' - ' + @NOMESGT;
		END
		
		DECLARE cPedidos CURSOR FAST_FORWARD FOR
		SELECT C.AD_PEDORIGINAL, C.CODPARC
		FROM sankhya.TGFITE AS I WITH (NOLOCK)
		INNER JOIN sankhya.TGFCAB AS C WITH (NOLOCK)
		ON C.NUNOTA = I.NUNOTA
		AND C.PENDENTE = 'S'
		AND C.TIPMOV = 'P'
		WHERE I.CODPROD =  @FIELD_CODPROD
		AND NOT EXISTS (
			SELECT 1
			FROM sankhya.TGFCAB AS C2 WITH (NOLOCK)
			WHERE C2.AD_PEDORIGINAL = C.AD_PEDORIGINAL
			AND C2.AD_CODREENVIO = C.AD_CODREENVIO
			AND C2.TIPMOV = 'V'
		)
		AND NOT EXISTS (
			SELECT 1 
			FROM EDITORAWVWEBPRD.dbo.TBLVWSAC AS S WITH (NOLOCK)
			WHERE S.NUPEDIDO = CAST(C.AD_PEDORIGINAL AS VARCHAR)
			AND S.CDTIPOSAC = 20
			AND S.DSSAC LIKE '%' + CAST(I.CODPROD AS VARCHAR) + '%'
		)

		OPEN cPedidos;

		FETCH NEXT FROM cPedidos
		INTO @PEDORIGINAL, @CODPARC;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			SET @SACS = @SACS + 1;

			SELECT @CDSAC = VLPROXIMOCODIGO FROM EDITORAWVWEBPRD.dbo.TBWMWPROXIMOCODIGO WHERE NMENTIDADE = 'TBLVWSAC';

			SET @CDSAC = @CDSAC + 1;

			INSERT INTO EDITORAWVWEBPRD.dbo.TBLVWSAC (CDEMPRESA, CDSAC, CDTIPOSAC, CDSUBTIPOSAC, DSSAC, CDREPRESENTANTE, CDCLIENTE, CDSTATUSSAC, NUPEDIDO, CDUSUARIOSAC, DTCADASTRO, FLATIVO, HRCADASTRO) 
			VALUES (1, @CDSAC, 20, NULL, @MSG, '0', @CODPARC, '1', @PEDORIGINAL, @CDUSUARIO, CONVERT(DATE, GETDATE()), 'S', CONVERT(VARCHAR(5), GETDATE(),108));

			UPDATE EDITORAWVWEBPRD.dbo.TBWMWPROXIMOCODIGO SET VLPROXIMOCODIGO = @CDSAC WHERE NMENTIDADE = 'TBLVWSAC';

			FETCH NEXT FROM cPedidos
			INTO @PEDORIGINAL, @CODPARC;
		END
		CLOSE cPedidos;
		DEALLOCATE cPedidos;

		SET @I = @I + 1
	END

	SET @I = @I - 1;
	SET @P_MENSAGEM = 'Foram abertos ' + CAST(@SACS AS VARCHAR) + ' SACs para substituir ' + CAST(@I AS VARCHAR) + ' produto(s)';
END
