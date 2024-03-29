USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFPRO_AD_MULTILOJA]    Script Date: 03/10/2018 19:24:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2013-09-07
	Description:	Atualiza o campo DTALTER na tabela AD_MULTILOJA na linha referente a este produto para que
					o produto seja capturado pela próxima exportação de catálogo (Integração Service)

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-04
	Description:	Melhorado performance e adicionado comentários.
					Se o nome do produto começar com 'D.' muda a categoria para 89 (INATIVO) na AD_PRODUTOLOJA

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-05
	Description:	Obtém o código da marca na AD_MARCASVTEX caso o código tenha mudado
					Não atualiza mais o campo complemento na AD_MULTILOJA (ele foi removido, agora é campo calculado)
					
	Author:			Guilherme Branco Stracini
	Change date:	2017-05-04
	Description:	Verifica se a flag "Aceita venda fora do KIT" está marcada, se não estiver remove o produto de venda
					da multiloja

	Author:			Rodrigo Lacalendola
	Change date:	2017-09-04
	Description:	Insere na tela de Logs de Alterações de Produtos VTEX

	Author:			Guilherme Branco Stracini
	Change date:	2018-10-03
	Description:	Valida o campo AD_CODPRODSUBSTITUTO - Se pode ser usado e  troca produtos na AD_AGENDADEMIDIA

	=============================================*/
ALTER TRIGGER [sankhya].[TRG_UPD_TGFPRO_AD_MULTILOJA] 
   ON  [sankhya].[TGFPRO] 
   AFTER UPDATE
AS 
DECLARE 
@CODPROD INT,
@DESCRPROD VARCHAR(100),
@COMPLEMENTO VARCHAR(100),
@ATIVO CHAR(1),
@CODUSU INT,
@CODMARCA INT,
@VENDAFORAKIT CHAR(1),
@CODPRODSUB INT,
@SOLICITANTE VARCHAR(30)
BEGIN
	SET NOCOUNT ON;

	/*
	 *	Obtém as informações do produto na TGFPRO (INSERTED)
	 */
	SELECT	@CODPROD =		I.CODPROD, 
			@DESCRPROD =	I.DESCRPROD,
			@COMPLEMENTO =	I.COMPLDESC, 
			@ATIVO =		I.ATIVO, 
			@CODUSU =		I.CODUSU,
			@VENDAFORAKIT = I.VENCOMPINDIV,
			@CODMARCA =		M.CODMARCA,
			@CODPRODSUB =	I.AD_CODPRODSUBSTITUTO
	FROM INSERTED AS I
	LEFT JOIN AD_MARCASVTEX AS M WITH (NOLOCK)
	ON M.NOME = I.MARCA;

	
	IF @CODPRODSUB IS NOT NULL 
	AND @CODPRODSUB > 0
	BEGIN

		/*
		 * Valida se foi preenchido o código do produto substituto e se é permitido (O produto precisa ser D. OU estar inativo (ATIVO = 'N'))
		 */
		IF @DESCRPROD NOT LIKE 'D.%' 
		AND @ATIVO = 'S'
		BEGIN
			RAISERROR('O código do produto substituto deve ser informado no produto D. %i, não no novo produto!', 16, 1, @CODPROD);
			SELECT @SOLICITANTE = program_name FROM MASTER.DBO.SYSPROCESSES WHERE SPID = @@SPID;
			IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%' 
			OR @SOLICITANTE = 'MS SQLEM'
			OR @SOLICITANTE = 'MS SQL QUERY ANALYZER'
			OR UPPER(@SOLICITANTE) LIKE 'TOAD%'
				ROLLBACK TRANSACTION;
		END
	
		/*
		 * Valida se o produto substituto está ativo
		 */
		IF EXISTS (SELECT 1 FROM sankhya.TGFPRO WITH (NOLOCK) WHERE CODPROD = @CODPRODSUB AND (ATIVO = 'N' OR DESCRPROD LIKE 'D.%'))
		BEGIN
			RAISERROR('O produto substituto %i deve estar ativo e não ser D.!', 16, 1, @CODPRODSUB);
			SELECT @SOLICITANTE = program_name FROM MASTER.DBO.SYSPROCESSES WHERE SPID = @@SPID;
			IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%' 
			OR @SOLICITANTE = 'MS SQLEM'
			OR @SOLICITANTE = 'MS SQL QUERY ANALYZER'
			OR UPPER(@SOLICITANTE) LIKE 'TOAD%'
				ROLLBACK TRANSACTION;
		END

		/*
		 * Atualiza os produtos substitutos que tem este produto como substituto
		 */
		IF (@ATIVO = 'N' OR @DESCRPROD LIKE 'D.%')
		AND EXISTS (SELECT 1 FROM sankhya.TGFPRO WITH (NOLOCK) WHERE AD_CODPRODSUBSTITUTO = @CODPROD)
			UPDATE sankhya.TGFPRO
			SET AD_CODPRODSUBSTITUTO = @CODPRODSUB
			WHERE AD_CODPRODSUBSTITUTO = @CODPROD;

		/*
		 * Atualiza na agenda de mídia o produto substituto
		 */
		IF (@ATIVO = 'N' OR @DESCRPROD LIKE 'D.%')
		AND EXISTS (SELECT 1 FROM sankhya.AD_AGENDAMIDIAS WITH (NOLOCK) WHERE CODPROD = @CODPROD)
			UPDATE sankhya.AD_AGENDAMIDIAS
			SET CODPROD = @CODPRODSUB
			WHERE CODPROD = @CODPROD;
	END
	ELSE IF EXISTS (SELECT 1 FROM sankhya.AD_AGENDAMIDIAS WITH (NOLOCK) WHERE CODPROD = @CODPROD AND [DATA] >= GETDATE())
	BEGIN
		RAISERROR('Existem agendas de mídia com o produto %i, por favor informe um código válido de produto substituto!', 16, 1, @CODPROD);
			SELECT @SOLICITANTE = program_name FROM MASTER.DBO.SYSPROCESSES WHERE SPID = @@SPID;
			IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%' 
			OR @SOLICITANTE = 'MS SQLEM'
			OR @SOLICITANTE = 'MS SQL QUERY ANALYZER'
			OR UPPER(@SOLICITANTE) LIKE 'TOAD%'
				ROLLBACK TRANSACTION;
	END
	
	/*
	 * Atualiza a Multiloja, alterando a data de modificação
	 * a flag de alteração no produto para SIM
	 * e a flag de alteração de estoque, somente se o campo AD_PESTNEG for atualizado, caso contrário mantem o valor que já existe
	 * e a marca, caso ela tenha sido alterada
	 */

	UPDATE AD_MULTILOJA
	SET DTMODIF =		GETDATE(),
		ALTPRODUTO =	'S',
		ALTESTOQUE =	CASE WHEN UPDATE(AD_PESTNEG) THEN 'S' ELSE ALTESTOQUE END,
		CODMARCA =		CASE WHEN UPDATE(MARCA) AND @CODMARCA IS NOT NULL THEN @CODMARCA ELSE CODMARCA END
	WHERE CODPROD = @CODPROD;

	/* Insere na tela de Logs de Alterações de Produtos VTEX */
	INSERT INTO AD_LOGALTERACOESVTEX (CODPROD, DTALTER, OCORRENCIA)
	SELECT CODPROD, GETDATE(), 'Produto alterado' FROM INSERTED

	/*
	 * Atualiza nos Canais de Vendas (Multiloja->Canais de Venda) o produto para inativo caso ele tenha sido inativado ou
	 * caso a flag 'Aceitar vender fora do KIT' não esteja marcada.
	 * Se o nome do produto começar com 'D.' altera o código da categoria para 89 (INATIVO)
	 * Caso contrário permanece na categoria para quando voltar a vender, não gerar retrabalho configurando categoria novamente.
	 */

	IF ((UPDATE(ATIVO) AND @ATIVO = 'N')
	OR (UPDATE(VENCOMPINDIV) AND @VENDAFORAKIT != 'S')) AND EXISTS (SELECT CODPROD FROM sankhya.AD_PRODUTOLOJA WITH(NOLOCK) WHERE CODLOJA IN (0,1,3) AND CODPROD = @CODPROD)
		UPDATE AD_PRODUTOLOJA
		SET DTALTER =	GETDATE(),
			ATIVO =		'N',
			CODUSU =	@CODUSU,
			CODCAT =	CASE WHEN @DESCRPROD LIKE 'D.%' THEN 89 ELSE CODCAT END
		WHERE CODPROD = @CODPROD;
END
